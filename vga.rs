static VGA_ADDRESS: uint = 0xb8000;

static VGA_WIDTH  : u16 = 80;
static VGA_HEIGHT : u16 = 24;

static mut curr_x: u16 = 0;
static mut curr_y: u16 = 0;

static mut fg_color: Color = Green;
static mut bg_color: Color = Black;

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

fn range(lo: uint, hi: uint, it: |uint| ) {
    let mut iter = lo;
    while iter < hi {
        it(iter);
        iter += 1;
    }
}

fn make_vgaentry(c: char, fg: Color, bg: Color) -> u16 {
    let color = fg as u16 | (bg as u16 << 4);
    return c as u16 | (color << 8);
}

pub fn clear_screen() {
    unsafe {
        range(0, 80*25, |i| {
            *((VGA_ADDRESS + i * 2) as *mut u16) = make_vgaentry('\0', fg_color, bg_color);

        });
    }
}

pub fn backspace() {
    unsafe {
        if curr_x == 0 {
            curr_y -= 1;
            curr_x = VGA_WIDTH - 1;
        } else {
            curr_x -= 1;
        }
        putchar(curr_x, curr_y, '\0');
    }
}

pub fn putc(c: char) {
    unsafe {
        putchar(curr_x, curr_y, c);
        curr_x += 1;
        if curr_x > VGA_WIDTH {
            curr_x -= VGA_WIDTH;
            curr_y += 1;
        }
    }
}

pub fn newline() {
    unsafe {
        curr_x = 0;
        curr_y += 1;
    }
}

pub fn putchar(x: u16, y: u16, c: char) {
    if x >= VGA_WIDTH || y >= VGA_HEIGHT {
        return;
    }
    let idx : uint =  (y * VGA_WIDTH * 2 + x * 2) as uint;
    unsafe {
        *((VGA_ADDRESS + idx) as *mut u16) = make_vgaentry(c, fg_color, bg_color);
    }
}
