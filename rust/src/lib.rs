#[cfg(target_os = "android")]
use jni::EnvUnowned;
#[cfg(target_os = "android")]
use jni::objects::{JClass, JObject};
#[cfg(target_os = "android")]
use jni::sys::jboolean;

pub mod api;
pub(crate) mod frb_api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

#[cfg(test)]
pub(crate) mod test_support;

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub extern "system" fn Java_com_edicl_mikan_1player_RustlsVerifier_init(
    mut env: EnvUnowned,
    _class: JClass,
    context: JObject,
) -> jboolean {
    let outcome: jni::Outcome<(), jni::errors::Error> = env
        .with_env(|env| {
            rustls_platform_verifier::android::init_with_env(env, context)
                .map_err(jni::errors::Error::from)
        })
        .into_outcome();
    match outcome {
        jni::Outcome::Ok(_) => jni::sys::JNI_TRUE,
        jni::Outcome::Err(err) => {
            log::error!("Failed to initialize rustls-platform-verifier: {err}");
            jni::sys::JNI_FALSE
        }
        jni::Outcome::Panic(_) => {
            log::error!("Failed to initialize rustls-platform-verifier: panic during init");
            jni::sys::JNI_FALSE
        }
    }
}
