use anyhow::{Context, Result, anyhow};
use image::imageops::FilterType;
use image::{DynamicImage, GenericImageView, Rgba, RgbaImage};
use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use tract_onnx::prelude::*;

type CaptchaModel = Arc<TypedSimplePlan>;

lazy_static! {
    static ref CAPTCHA_ENGINE: Mutex<Option<CaptchaOcrEngine>> = Mutex::new(None);
}

#[derive(Debug, Deserialize)]
struct CharsetFile {
    charset: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CaptchaConstraintOptions {
    pub allowed_chars: Option<String>,
    pub expected_length: Option<u32>,
    pub enable_lookalike_mapping: bool,
}

struct CaptchaOcrEngine {
    model_path: PathBuf,
    charset_path: PathBuf,
    charset: Vec<String>,
    model: CaptchaModel,
}

impl CaptchaOcrEngine {
    fn load(model_path: impl AsRef<Path>, charset_path: impl AsRef<Path>) -> Result<Self> {
        let model_path = model_path.as_ref().to_path_buf();
        let charset_path = charset_path.as_ref().to_path_buf();

        let charset_file = fs::read_to_string(&charset_path)
            .with_context(|| format!("failed to read charset file: {}", charset_path.display()))?;
        let charset: CharsetFile = serde_json::from_str(&charset_file)
            .with_context(|| format!("failed to parse charset file: {}", charset_path.display()))?;

        if charset.charset.is_empty() {
            return Err(anyhow!("charset file is empty"));
        }

        let model = tract_onnx::onnx()
            .model_for_path(&model_path)
            .with_context(|| format!("failed to load model: {}", model_path.display()))?
            .into_optimized()
            .context("failed to optimize captcha model")?
            .into_runnable()
            .context("failed to create runnable captcha model")?;

        Ok(Self {
            model_path,
            charset_path,
            charset: charset.charset,
            model,
        })
    }

    fn recognize(
        &self,
        image_bytes: &[u8],
        png_fix: bool,
        options: Option<CaptchaConstraintOptions>,
    ) -> Result<String> {
        let tensor = preprocess_image(image_bytes, png_fix)?;
        let outputs = self
            .model
            .run(tvec!(tensor.into()))
            .context("captcha model inference failed")?;
        let output = outputs
            .into_iter()
            .next()
            .context("captcha model returned no outputs")?
            .into_tensor();

        decode_output(&self.charset, output, options.as_ref())
    }
}

pub async fn initialize_captcha_ocr(model_path: String, charset_path: String) -> Result<()> {
    tokio::task::spawn_blocking(move || {
        let engine = CaptchaOcrEngine::load(&model_path, &charset_path)?;
        let mut guard = CAPTCHA_ENGINE
            .lock()
            .map_err(|_| anyhow!("captcha OCR mutex poisoned"))?;
        *guard = Some(engine);
        Ok(())
    })
    .await
    .context("captcha OCR init task join failed")?
}

pub async fn recognize_captcha(image_bytes: Vec<u8>, png_fix: bool) -> Result<String> {
    tokio::task::spawn_blocking(move || {
        let guard = CAPTCHA_ENGINE
            .lock()
            .map_err(|_| anyhow!("captcha OCR mutex poisoned"))?;
        let engine = guard
            .as_ref()
            .context("captcha OCR engine is not initialized")?;
        engine.recognize(&image_bytes, png_fix, None)
    })
    .await
    .context("captcha OCR task join failed")?
}

pub async fn recognize_captcha_with_constraints(
    image_bytes: Vec<u8>,
    png_fix: bool,
    options: CaptchaConstraintOptions,
) -> Result<String> {
    tokio::task::spawn_blocking(move || {
        let guard = CAPTCHA_ENGINE
            .lock()
            .map_err(|_| anyhow!("captcha OCR mutex poisoned"))?;
        let engine = guard
            .as_ref()
            .context("captcha OCR engine is not initialized")?;
        engine.recognize(&image_bytes, png_fix, Some(options))
    })
    .await
    .context("captcha OCR task join failed")?
}

pub fn is_captcha_ocr_initialized() -> bool {
    CAPTCHA_ENGINE
        .lock()
        .map(|guard| guard.is_some())
        .unwrap_or(false)
}

pub fn get_captcha_ocr_model_info() -> String {
    match CAPTCHA_ENGINE.lock() {
        Ok(guard) => match guard.as_ref() {
            Some(engine) => format!(
                "model={}, charset={}, charset_size={}",
                engine.model_path.display(),
                engine.charset_path.display(),
                engine.charset.len()
            ),
            None => "captcha OCR not initialized".to_string(),
        },
        Err(_) => "captcha OCR mutex poisoned".to_string(),
    }
}

fn preprocess_image(image_bytes: &[u8], png_fix: bool) -> Result<Tensor> {
    let image = image::load_from_memory(image_bytes).context("failed to decode captcha image")?;
    let image = if png_fix {
        flatten_on_white(image)
    } else {
        image
    };

    let (original_width, original_height) = image.dimensions();
    if original_width == 0 || original_height == 0 {
        return Err(anyhow!("captcha image has invalid dimensions"));
    }

    let target_height = 64u32;
    let target_width = ((original_width as f32 * (target_height as f32 / original_height as f32))
        .floor())
    .max(1.0) as u32;

    let resized = image.resize_exact(target_width, target_height, FilterType::Lanczos3);
    let gray = resized.into_luma8();
    let input: Vec<f32> = gray.pixels().map(|pixel| pixel[0] as f32 / 255.0).collect();

    let tensor = tract_ndarray::Array4::from_shape_vec(
        (1, 1, target_height as usize, target_width as usize),
        input,
    )
    .context("failed to build captcha input tensor")?
    .into_tensor();

    Ok(tensor)
}

fn flatten_on_white(image: DynamicImage) -> DynamicImage {
    let rgba = image.into_rgba8();
    let (width, height) = rgba.dimensions();
    let mut background = RgbaImage::from_pixel(width, height, Rgba([255, 255, 255, 255]));

    for (x, y, pixel) in rgba.enumerate_pixels() {
        let alpha = pixel[3] as f32 / 255.0;
        let inv_alpha = 1.0 - alpha;
        let blended = Rgba([
            (pixel[0] as f32 * alpha + 255.0 * inv_alpha).round() as u8,
            (pixel[1] as f32 * alpha + 255.0 * inv_alpha).round() as u8,
            (pixel[2] as f32 * alpha + 255.0 * inv_alpha).round() as u8,
            255,
        ]);
        background.put_pixel(x, y, blended);
    }

    DynamicImage::ImageRgba8(background)
}

fn decode_output(
    charset: &[String],
    output: Tensor,
    options: Option<&CaptchaConstraintOptions>,
) -> Result<String> {
    let output = output
        .to_plain_array_view::<f32>()
        .context("failed to read captcha output tensor as f32")?;
    let shape = output.shape();
    let allowed_indices = options.map(|item| build_allowed_indices(charset, item));

    let predicted = match shape {
        [sequence_len, 1, classes] => {
            let mut indices = Vec::with_capacity(*sequence_len);
            for time_step in 0..*sequence_len {
                indices.push(argmax_3d(
                    &output,
                    [time_step, 0, 0],
                    *classes,
                    AxisOrder::SeqBatchClass,
                    allowed_indices.as_deref(),
                ));
            }
            indices
        }
        [1, sequence_len, classes] => {
            let mut indices = Vec::with_capacity(*sequence_len);
            for time_step in 0..*sequence_len {
                indices.push(argmax_3d(
                    &output,
                    [0, time_step, 0],
                    *classes,
                    AxisOrder::BatchSeqClass,
                    allowed_indices.as_deref(),
                ));
            }
            indices
        }
        [sequence_len, classes] => {
            let mut indices = Vec::with_capacity(*sequence_len);
            for time_step in 0..*sequence_len {
                indices.push(argmax_2d(
                    &output,
                    time_step,
                    *classes,
                    allowed_indices.as_deref(),
                ));
            }
            indices
        }
        other => {
            return Err(anyhow!("unsupported captcha output shape: {other:?}"));
        }
    };

    let decoded = ctc_decode(charset, predicted);
    Ok(apply_constraints(decoded, options))
}

enum AxisOrder {
    SeqBatchClass,
    BatchSeqClass,
}

fn argmax_3d(
    output: &tract_ndarray::ArrayViewD<'_, f32>,
    start: [usize; 3],
    classes: usize,
    order: AxisOrder,
    allowed_indices: Option<&[usize]>,
) -> usize {
    let mut best_index = 0usize;
    let mut best_score = f32::NEG_INFINITY;

    let candidate_indices = allowed_indices
        .map(|indices| indices.to_vec())
        .unwrap_or_else(|| (0..classes).collect());

    for class_index in candidate_indices {
        let score = match order {
            AxisOrder::SeqBatchClass => output[[start[0], start[1], class_index]],
            AxisOrder::BatchSeqClass => output[[start[0], start[1], class_index]],
        };
        if score > best_score {
            best_score = score;
            best_index = class_index;
        }
    }

    best_index
}

fn argmax_2d(
    output: &tract_ndarray::ArrayViewD<'_, f32>,
    time_step: usize,
    classes: usize,
    allowed_indices: Option<&[usize]>,
) -> usize {
    let mut best_index = 0usize;
    let mut best_score = f32::NEG_INFINITY;

    let candidate_indices = allowed_indices
        .map(|indices| indices.to_vec())
        .unwrap_or_else(|| (0..classes).collect());

    for class_index in candidate_indices {
        let score = output[[time_step, class_index]];
        if score > best_score {
            best_score = score;
            best_index = class_index;
        }
    }

    best_index
}

fn ctc_decode(charset: &[String], predicted: Vec<usize>) -> String {
    let mut decoded = String::new();
    let mut previous = None;

    for index in predicted {
        if previous == Some(index) {
            continue;
        }
        previous = Some(index);

        if index == 0 {
            continue;
        }

        if let Some(character) = charset.get(index) {
            decoded.push_str(character);
        }
    }

    decoded
}

fn build_allowed_indices(charset: &[String], options: &CaptchaConstraintOptions) -> Vec<usize> {
    let mut allowed = vec![0usize];

    let Some(allowed_chars) = &options.allowed_chars else {
        return allowed;
    };

    let allowed_set: HashSet<String> = allowed_chars.chars().map(|item| item.to_string()).collect();
    for (index, item) in charset.iter().enumerate().skip(1) {
        if allowed_set.contains(item) {
            allowed.push(index);
        }
    }

    allowed.sort_unstable();
    allowed.dedup();
    allowed
}

fn apply_constraints(decoded: String, options: Option<&CaptchaConstraintOptions>) -> String {
    let Some(options) = options else {
        return decoded;
    };

    let Some(allowed_chars) = &options.allowed_chars else {
        return apply_expected_length(decoded, options.expected_length);
    };

    let allowed_set: HashSet<char> = allowed_chars.chars().collect();
    let lookalike_map = if options.enable_lookalike_mapping {
        build_lookalike_map()
    } else {
        HashMap::new()
    };

    let mut constrained = String::new();
    for character in decoded.chars() {
        if allowed_set.contains(&character) {
            constrained.push(character);
            continue;
        }

        if let Some(mapped) = lookalike_map.get(&character)
            && allowed_set.contains(mapped)
        {
            constrained.push(*mapped);
        }
    }

    apply_expected_length(constrained, options.expected_length)
}

fn apply_expected_length(input: String, expected_length: Option<u32>) -> String {
    let Some(expected_length) = expected_length else {
        return input;
    };

    input.chars().take(expected_length as usize).collect()
}

fn build_lookalike_map() -> HashMap<char, char> {
    [
        ('o', '0'),
        ('O', '0'),
        ('Q', '0'),
        ('D', '0'),
        ('I', '1'),
        ('l', '1'),
        ('L', '1'),
        ('|', '1'),
        ('Z', '7'),
        ('z', '7'),
        ('T', '7'),
        ('S', '5'),
        ('s', '5'),
        ('B', '8'),
        ('b', '6'),
        ('G', '6'),
        ('g', '9'),
        ('A', '4'),
    ]
    .into_iter()
    .collect()
}

#[cfg(test)]
mod tests {
    use super::{CaptchaConstraintOptions, CaptchaOcrEngine, apply_constraints, ctc_decode};
    use image::{DynamicImage, ImageFormat, Rgba, RgbaImage};
    use std::io::Cursor;
    use std::path::PathBuf;

    #[test]
    fn ctc_decode_removes_blanks_and_repeats() {
        let charset = vec![
            "".to_string(),
            "A".to_string(),
            "B".to_string(),
            "C".to_string(),
        ];

        let result = ctc_decode(&charset, vec![0, 1, 1, 0, 2, 2, 3, 0, 3]);
        assert_eq!(result, "ABCC");
    }

    #[test]
    fn beta_model_smoke_test() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("workspace root")
            .to_path_buf();
        let model_path = root.join("assets").join("ocr").join("common.onnx");
        let charset_path = root
            .join("assets")
            .join("ocr")
            .join("common_beta_charset.json");

        let engine = CaptchaOcrEngine::load(&model_path, &charset_path)
            .expect("captcha engine should load common.onnx");

        let image = RgbaImage::from_pixel(160, 64, Rgba([255, 255, 255, 255]));
        let mut png_bytes = Vec::new();
        DynamicImage::ImageRgba8(image)
            .write_to(&mut Cursor::new(&mut png_bytes), ImageFormat::Png)
            .expect("should encode png");

        let result = engine
            .recognize(&png_bytes, false, None)
            .expect("captcha inference should succeed");
        assert!(result.chars().count() <= 32);
    }

    #[test]
    fn constrained_postprocess_maps_lookalikes_for_digits() {
        let options = CaptchaConstraintOptions {
            allowed_chars: Some("0123456789".to_string()),
            expected_length: Some(4),
            enable_lookalike_mapping: true,
        };

        let result = apply_constraints("zO1S8".to_string(), Some(&options));
        assert_eq!(result, "7015");
    }
}
