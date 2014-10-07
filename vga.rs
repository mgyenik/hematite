use super::core::prelude::*;
use super::core::mem;
use super::core::fmt;
use super::core::iter;

static VGA_ADDRESS: uint = 0xb8000;

static VGA_WIDTH  : u16 = 80;
static VGA_HEIGHT : u16 = 24;

pub enum Color {
    Black       = 0,
    Blue        = 1,
    Green       = 2,
    Cyan        = 3,
    Red         = 4,
    Pink        = 5,
    Brown       = 6,
    LightGray   = 7,
    DarkGray    = 8,
    LightBlue   = 9,
    LightGreen  = 10,
    LightCyan   = 11,
    LightRed    = 12,
    LightPink   = 13,
    Yellow      = 14,
    White       = 15,
}

fn make_vgaentry(c: char, fg: Color, bg: Color) -> u16 {
    let color = fg as u16 | (bg as u16 << 4);
    return c as u16 | (color << 8);
}

pub struct Console {
    vga_buffer: *mut u16,
    curr_x: u16,
    curr_y: u16,
    fg_color: Color,
    bg_color: Color,
}

impl Console {
    pub fn new(fg: Color, bg: Color) -> Console {
        Console{
            vga_buffer: unsafe{ mem::transmute(VGA_ADDRESS) },
            curr_x: 0,
            curr_y: 0,
            fg_color: fg,
            bg_color: bg,
        }
    }
}

impl Console {
    pub fn putc(&mut self, c: char) {
        if self.curr_x > VGA_WIDTH {
            self.curr_x = 0;
            self.curr_y += 1;
        }

        if self.curr_y > VGA_HEIGHT {
            self.curr_y = 0;
        }

        let idx : int =  (self.curr_y * VGA_WIDTH + self.curr_x) as int;
        unsafe {
            *self.vga_buffer.offset(idx) = make_vgaentry(c, self.fg_color, self.bg_color);
        }

        self.curr_x += 1
    }

    pub fn puts(&mut self, s: &str) {
        for c in s.chars() {
            self.putc(c);
        }
    }

    pub fn clear(&mut self) {
        self.curr_x = 0;
        self.curr_y = 0;

        for i in range(0u, 80*25) {
            self.putc(' ');
        }

        self.curr_x = 0;
        self.curr_y = 0;
    }

    pub fn newline(&mut self) {
        self.curr_x = 0;
        self.curr_y += 1;
    }

    pub fn backspace(&mut self) {
        if self.curr_x == 0 {
            self.curr_y -= 1;
            self.curr_x = VGA_WIDTH - 1;
        } else {
            self.curr_x -= 1;
        }

        self.putc('\0');
    }
}

impl fmt::FormatWriter for Console {
    fn write(&mut self, bytes: &[u8]) -> fmt::Result {
        for b in bytes.iter() {
            self.putc(*b as char);
        }
        Ok(())
    }
}
