#![no_std]
#![feature(globs, phase)]
#![feature(lang_items)]
#![no_split_stack]

#[phase(plugin, link)]
extern crate core;

use core::prelude::*;

mod vga;
mod e820;

#[start]
#[no_mangle]
pub fn start(_: int, _: *const *const u8) -> int {
    let mut console = vga::Console::new(vga::White, vga::DarkGray);
    let e820 = &mut e820::E820Info::new();

    console.clear();
    for region in e820 {
        console.puts("A");
    }

    loop {};
}
