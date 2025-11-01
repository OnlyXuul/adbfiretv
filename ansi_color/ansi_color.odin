package ansi_color

import "core:os"
import "core:fmt"
import "core:terminal"
import ansi "core:terminal/ansi"

/**************************************************************************************************
 * ANSI Color library that supports 3bit, 4bit, 8bit, and 24bit (TrueColor) printing to terminal.
 *
 * Procedures:
 * printfc(ansi_format: ANSI_Format, printf_format: string, args: ..any)
 * printfcln(ansi_format: ANSI_Format, printf_format: string, args: ..any)
 *
 * ANSI_Format union types (pass one of these to print procedures):
 * ANSI_3Bit
 * ANSI_4Bit
 * ANSI_8Bit
 * ANSI_24Bit
 ***************************************************************************************************/

/***********************************************************
 * Attribute used by all color formats
 * No way to check for these except to just try them
 * in the terminal.
 ***********************************************************/

Attribute :: enum u8 {
	BOLD                    = 1,
	FAINT                   = 2,
	ITALIC                  = 3,
	UNDERLINE               = 4,
	BLINK_SLOW              = 5,
	BLINK_RAPID             = 6, // Not widely supported.
	INVERT                  = 7, // Also known as reverse video.
	HIDE                    = 8, // Not widely supported.
	STRIKE                  = 9,
	FONT_PRIMARY            = 10,
	FONT_ALT1               = 11,
	FONT_ALT2               = 12,
	FONT_ALT3               = 13,
	FONT_ALT4               = 14,
	FONT_ALT5               = 15,
	FONT_ALT6               = 16,
	FONT_ALT7               = 17,
	FONT_ALT8               = 18,
	FONT_ALT9               = 19,
	FONT_FRAKTUR            = 20, // Rarely supported.
	UNDERLINE_DOUBLE        = 21, // May be interpreted as "disable bold."
	NO_BOLD_FAINT           = 22,
	NO_ITALIC_BLACKLETTER   = 23,
	NO_UNDERLINE            = 24,
	NO_BLINK                = 25,
	PROPORTIONAL_SPACING    = 26,
	NO_REVERSE              = 27,
	NO_HIDE                 = 28,
	NO_STRIKE               = 29,
	NO_PROPORTIONAL_SPACING = 50,
	FRAMED                  = 51, // Not widely supported.
	ENCIRCLED               = 52, // Not widely supported.
	OVERLINED               = 53,
	NO_FRAME_ENCIRCLE       = 54,
	NO_OVERLINE             = 55,
}

/***********************************************************
 * Union of ANSI Formats
 ***********************************************************/

ANSI_Format :: union {
	ANSI_3Bit,
	ANSI_4Bit,
	ANSI_8Bit,
	ANSI_24Bit,
}

/***********************************************************
 * 3 Bit Color Printing - 8 colors
 * Colors will be converted if the console is using a theme
 ***********************************************************/

ANSI_3Bit :: struct {
	fg:  FG_Color_3Bit,
	bg:  BG_Color_3Bit,
	att: bit_set[Attribute],
}

FG_Color_3Bit :: enum u8 {
	NONE       = 0,
	FG_BLACK   = 30,
	FG_RED     = 31,
	FG_GREEN   = 32,
	FG_YELLOW  = 33,
	FG_BLUE    = 34,
	FG_MAGENTA = 35,
	FG_CYAN    = 36,
	FG_WHITE   = 37,
	FG_DEFAULT = 39,
}

BG_Color_3Bit :: enum u8 {
	NONE       = 0,
	BG_BLACK   = 40,
	BG_RED     = 41,
	BG_GREEN   = 42,
	BG_YELLOW  = 43,
	BG_BLUE    = 44,
	BG_MAGENTA = 45,
	BG_CYAN    = 46,
	BG_WHITE   = 47,
	BG_DEFAULT = 49,
}

/***********************************************************
 * 4 Bit Color Printing - 16 colors
 * Colors will be converted if the console is using a theme
 ***********************************************************/

ANSI_4Bit :: struct {
	fg:  FG_Color_4Bit,
	bg:  BG_Color_4Bit,
	att: bit_set[Attribute],
}

FG_Color_4Bit :: enum u8 {
	NONE              = 0,
	FG_BLACK          = 30,
	FG_RED            = 31,
	FG_GREEN          = 32,
	FG_YELLOW         = 33,
	FG_BLUE           = 34,
	FG_MAGENTA        = 35,
	FG_CYAN           = 36,
	FG_WHITE          = 37,
	FG_DEFAULT        = 39,
	FG_BRIGHT_BLACK   = 90, // Also known as grey.
	FG_BRIGHT_RED     = 91,
	FG_BRIGHT_GREEN   = 92,
	FG_BRIGHT_YELLOW  = 93,
	FG_BRIGHT_BLUE    = 94,
	FG_BRIGHT_MAGENTA = 95,
	FG_BRIGHT_CYAN    = 96,
	FG_BRIGHT_WHITE   = 97,
}

BG_Color_4Bit :: enum u8 {
	NONE              = 0,
	BG_BLACK          = 40,
	BG_RED            = 41,
	BG_GREEN          = 42,
	BG_YELLOW         = 43,
	BG_BLUE           = 44,
	BG_MAGENTA        = 45,
	BG_CYAN           = 46,
	BG_WHITE          = 47,
	BG_DEFAULT        = 49,
	BG_BRIGHT_BLACK   = 100, // Also known as grey.
	BG_BRIGHT_RED     = 101,
	BG_BRIGHT_GREEN   = 102,
	BG_BRIGHT_YELLOW  = 103,
	BG_BRIGHT_BLUE    = 104,
	BG_BRIGHT_MAGENTA = 105,
	BG_BRIGHT_CYAN    = 106,
	BG_BRIGHT_WHITE   = 107,
}

/***********************************************************
 * 8 Bit Color Printing - 256 colors
 ***********************************************************/

ANSI_8Bit :: struct {
	fg:  Maybe(u8),
	bg:  Maybe(u8),
	att: bit_set[Attribute],
}

/***********************************************************
 * 24 Bit (TrueColor) Color Printing - 16.7 million colors
 ***********************************************************/

ANSI_24Bit :: struct {
	fg:  [3]Maybe(u8),
	bg:  [3]Maybe(u8),
	att: bit_set[Attribute],
}

/***********************************************************
 * Print procedures:
 * printfc
 * printfcln
 ***********************************************************/

printfc :: proc(ansi_format: ANSI_Format, printf_format: string, args: ..any) {
	fprintfc(ansi_format, printf_format, ..args, newline = false)
}

printfcln :: proc(ansi_format: ANSI_Format, printf_format: string, args: ..any) {
	fprintfc(ansi_format, printf_format, ..args, newline = true)
}

fprintfc :: proc(ansi_format: ANSI_Format, printf_format: string, args: ..any, newline := false) {

	get_attributes :: proc(attributes: bit_set[Attribute]) -> (att: string) {
		semi: string
		for a in attributes {
			semi = len(att) == 0 ? "" : ";"
			att = fmt.tprintf("%s%s%i", att, semi, a) }
			return
	}

	sgr_sequence, format, semi: string
	terminal_ok: bool

	switch af in ansi_format {
		case ANSI_3Bit:
			terminal_ok = terminal.color_enabled && terminal.color_depth >= .Three_Bit
			sgr_sequence = get_attributes(af.att)
			if af.fg != .NONE {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%i", sgr_sequence, semi, af.fg)
			}
			if af.bg != .NONE {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%i", sgr_sequence, semi, af.bg)
			}
		case ANSI_4Bit:
			terminal_ok = terminal.color_enabled && terminal.color_depth >= .Four_Bit
			sgr_sequence = get_attributes(af.att)
			if af.fg != .NONE {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%i", sgr_sequence, semi, af.fg)
			}
			if af.bg != .NONE {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%i", sgr_sequence, semi, af.bg)
			}
		case ANSI_8Bit:
			terminal_ok = terminal.color_enabled && terminal.color_depth >= .Eight_Bit
			sgr_sequence = get_attributes(af.att)
			if af.fg != nil {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%s%i", sgr_sequence, semi, ansi.FG_COLOR_8_BIT + ";", af.fg)
			}
			if af.bg != nil {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%s%i", sgr_sequence, semi, ansi.BG_COLOR_8_BIT + ";", af.bg)
			}
		case ANSI_24Bit:
			terminal_ok = terminal.color_enabled && terminal.color_depth >= .True_Color
			sgr_sequence = get_attributes(af.att)
			if af.fg.r != nil && af.fg.g != nil && af.fg.b != nil {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%s%i%s%i%s%i", sgr_sequence, semi, ansi.FG_COLOR_24_BIT + ";", af.fg.r, ";", af.fg.g, ";", af.fg.b)
			}
			if af.bg.r != nil && af.bg.g != nil && af.bg.b != nil {
				semi = len(sgr_sequence) == 0 ? "" : ";"
				sgr_sequence = fmt.tprintf("%s%s%s%i%s%i%s%i", sgr_sequence, semi, ansi.BG_COLOR_24_BIT + ";", af.bg.r, ";", af.bg.g, ";", af.bg.b)
			}
	}

	if (sgr_sequence != "") && terminal_ok {
		format = fmt.tprintf("%s%s%s%s%s", ansi.CSI, sgr_sequence, ansi.SGR, printf_format, ansi.CSI + ansi.RESET + ansi.SGR)
	}
	else {
		format = printf_format
	}

	fmt.fprintf(os.stdout, format, ..args, flush = true, newline = newline)
}
