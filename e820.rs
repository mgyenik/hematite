use super::core::prelude::*;
use super::core::mem;

#[repr(C)]
struct E820Entry {
    base: u64,
    length: u64,
    typ: u32,
    attr: u32,
}

pub struct E820Info {
    idx: int,
    num_entries: int,
    entries: *const E820Entry,
}

impl E820Info {
    pub fn new() -> E820Info {
        unsafe {
            let n: *const int = mem::transmute(0x8000u);
            E820Info{
                idx: 0,
                num_entries: *n,
                entries: mem::transmute(0x8004u)
            }
        }
    }
}

impl Iterator<E820Entry> for E820Info {
    fn next(&mut self) -> Option<E820Entry> {
        if self.idx < self.num_entries {
            self.idx += 1;
            Some(unsafe{ *self.entries.offset(self.idx) })
        } else {
            None
        }
    }
}
