#[cfg(target_os = "android")]
use jni::JNIEnv;
#[cfg(target_os = "android")]
use jni::objects::{JClass, JObject};
#[cfg(target_os = "android")]
use jni::sys::jboolean;

pub mod api;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

#[cfg(target_os = "android")]
#[unsafe(no_mangle)]
pub extern "system" fn Java_com_edicl_mikan_1player_RustlsVerifier_init(
    mut env: JNIEnv,
    _class: JClass,
    context: JObject,
) -> jboolean {
    match rustls_platform_verifier::android::init_with_env(&mut env, context) {
        Ok(_) => jni::sys::JNI_TRUE,
        Err(err) => {
            log::error!("Failed to initialize rustls-platform-verifier: {err}");
            jni::sys::JNI_FALSE
        }
    }
}
