use crate::api::network as network_impl;

pub fn get_system_proxy() -> Option<String> {
    network_impl::get_system_proxy()
}
