//// Based on https://github.com/kmcallister/rust/blob/8ccbf4f2d4c6d0755b6460d0b0809e442af2bd6d/src/test/run-pass/format-no-std.rs
// 
//#![feature(phase)]
//#![no_std]
// 
//#[phase(plugin, link)]
//extern crate core;
// 
//#[phase(plugin, link)]
//extern crate collections;
// 
//extern crate native;
// 
//use core::str::StrSlice;
// 
//#[no_split_stacks]
//fn main() {
//    let s = "Hello";
// 
//    for c in s.chars() {
//        //println!("{}", c);
//    }
//}

#![no_std]
#![feature(globs)]
#![feature(lang_items)]
#![no_split_stack]

extern crate core;

use core::prelude::*;

use core::mem;

#[no_mangle]
pub extern fn dot_product(a: *const u32, a_len: u32,
                          b: *const u32, b_len: u32) -> u32 {
    use core::raw::Slice;

    // Convert the provided arrays into Rust slices.
    // The core::raw module guarantees that the Slice
    // structure has the same memory layout as a &[T]
    // slice.
    //
    // This is an unsafe operation because the compiler
    // cannot tell the pointers are valid.
    let (a_slice, b_slice): (&[u32], &[u32]) = unsafe {
        mem::transmute((
            Slice { data: a, len: a_len as uint },
            Slice { data: b, len: b_len as uint },
        ))
    };

    // Iterate over the slices, collecting the result
    let mut ret = 0;
    for (i, j) in a_slice.iter().zip(b_slice.iter()) {
        ret += (*i) * (*j);
    }
    return ret;
}

//extern crate core;

//use core::prelude::*;

mod vga;

pub fn write(s: &str) {
    for c in s.chars() {
        vga::putc(c);
    }
}

//#[no_mangle]
//fn __morestack() {
//    let mut a = 0i;
//    loop { a += 1;};
//}

#[start]
#[no_mangle]
pub fn start(_: int, _: *const *const u8) -> int {
    vga::clear_screen();
    //write("Hello from rust!");
    vga::silly_bss();
    vga::putc('R');
    vga::putc('U');
    vga::putc('S');
    vga::putc('T');
    vga::putc('!');
    vga::putc(' ');
    vga::putc(':');
    vga::putc('D');
    loop {};
    return 0;
}

#[lang = "stack_exhausted"]
fn stack_exhausted() {
    loop {};
}

#[lang = "eh_personality"]
fn eh_personality() {
    loop {};
}

#[lang = "begin_unwind"]
fn begin_unwind() {
    loop {};
}
