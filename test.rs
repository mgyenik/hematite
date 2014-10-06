#![no_std]
#![feature(globs)]
#![feature(lang_items)]
#![no_split_stack]

extern crate core;

use core::prelude::*;

mod vga;

pub fn write(s: &str) {
    for c in s.chars() {
        vga::putc(c);
    }
}

#[start]
#[no_mangle]
pub fn start(_: int, _: *const *const u8) -> int {
    vga::clear_screen();
    write("Hello from rust!");
    loop {};
}
