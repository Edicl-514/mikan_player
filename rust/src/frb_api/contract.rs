pub(super) fn public_result<T>(api_name: &str, result: anyhow::Result<T>) -> anyhow::Result<T> {
    result.map_err(|error| anyhow::anyhow!("{api_name}: {error:#}"))
}

pub(super) fn require_positive_i64(name: &str, value: i64) -> anyhow::Result<()> {
    if value > 0 {
        Ok(())
    } else {
        Err(invalid_argument(name, "must be greater than zero"))
    }
}

pub(super) fn require_non_blank(name: &str, value: &str) -> anyhow::Result<()> {
    if value.trim().is_empty() {
        Err(invalid_argument(name, "must not be blank"))
    } else {
        Ok(())
    }
}

pub(super) fn require_i32_range(name: &str, value: i32, min: i32, max: i32) -> anyhow::Result<()> {
    if (min..=max).contains(&value) {
        Ok(())
    } else {
        Err(invalid_argument(
            name,
            &format!("must be between {min} and {max}"),
        ))
    }
}

pub(super) fn require_non_negative_i32(name: &str, value: i32) -> anyhow::Result<()> {
    if value >= 0 {
        Ok(())
    } else {
        Err(invalid_argument(name, "must not be negative"))
    }
}

pub(super) fn require_one_of(name: &str, value: &str, allowed: &[&str]) -> anyhow::Result<()> {
    if allowed.contains(&value) {
        Ok(())
    } else {
        Err(invalid_argument(
            name,
            &format!("must be one of: {}", allowed.join(", ")),
        ))
    }
}

pub(super) fn require_quarter(name: &str, value: &str) -> anyhow::Result<()> {
    let bytes = value.as_bytes();
    let valid = bytes.len() == 6
        && bytes[..4].iter().all(u8::is_ascii_digit)
        && bytes[4] == b'q'
        && matches!(bytes[5], b'1'..=b'4');
    if valid {
        Ok(())
    } else {
        Err(invalid_argument(name, "must match YYYYq1 through YYYYq4"))
    }
}

pub(super) fn require_non_blank_items(name: &str, values: &[String]) -> anyhow::Result<()> {
    if let Some(index) = values.iter().position(|value| value.trim().is_empty()) {
        Err(invalid_argument(
            name,
            &format!("item at index {index} must not be blank"),
        ))
    } else {
        Ok(())
    }
}

pub(super) fn require_positive_decimal_items(name: &str, values: &[String]) -> anyhow::Result<()> {
    if let Some((index, _)) = values.iter().enumerate().find(|(_, value)| {
        value.is_empty()
            || !value.bytes().all(|byte| byte.is_ascii_digit())
            || value.bytes().all(|byte| byte == b'0')
    }) {
        Err(invalid_argument(
            name,
            &format!("item at index {index} must be a positive decimal ID"),
        ))
    } else {
        Ok(())
    }
}

fn invalid_argument(name: &str, expectation: &str) -> anyhow::Error {
    anyhow::anyhow!("invalid argument `{name}`: {expectation}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validation_errors_are_stable_and_public_errors_are_single_line() {
        let error = public_result::<()>("fetch_example", require_positive_i64("subject_id", 0))
            .unwrap_err();
        assert_eq!(
            error.to_string(),
            "fetch_example: invalid argument `subject_id`: must be greater than zero"
        );

        let nested = anyhow::anyhow!("inner").context("outer");
        let error = public_result::<()>("fetch_example", Err(nested)).unwrap_err();
        assert_eq!(error.to_string(), "fetch_example: outer: inner");
        assert!(!error.to_string().contains('\n'));
    }

    #[test]
    fn quarter_and_collection_item_validation_reject_malformed_input() {
        for valid in ["1963q1", "2026q4"] {
            require_quarter("year_quarter", valid).unwrap();
        }
        for invalid in ["", "2026Q1", "2026q0", "2026q5", "中文q1", "20261"] {
            assert!(require_quarter("year_quarter", invalid).is_err());
        }

        require_positive_decimal_items("existing_ids", &["1".to_string(), "0002".to_string()])
            .unwrap();
        for invalid in [
            vec!["0".to_string()],
            vec!["-1".to_string()],
            vec![String::new()],
        ] {
            assert!(require_positive_decimal_items("existing_ids", &invalid).is_err());
        }
    }
}
