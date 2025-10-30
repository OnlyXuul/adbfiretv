package ansi_color_text

import "core:fmt"

/***********************************************************
 * Constants for testing
 ***********************************************************/

nocolor_3bit :: ANSI_3Bit{}
hello_3bit   :: ANSI_3Bit{fg = .FG_GREEN}
world_3bit   :: ANSI_3Bit{fg = .FG_CYAN}
error_3bit   :: ANSI_3Bit{fg = .FG_RED}
warning_3bit :: ANSI_3Bit{fg = .FG_YELLOW}
heading_3bit :: ANSI_3Bit{fg = .FG_WHITE, bg = .BG_MAGENTA, att = {.UNDERLINE, .ITALIC}}

nocolor_4bit :: ANSI_4Bit{}
hello_4bit   :: ANSI_4Bit{fg = .FG_BRIGHT_GREEN}
world_4bit   :: ANSI_4Bit{fg = .FG_BRIGHT_CYAN}
error_4bit   :: ANSI_4Bit{fg = .FG_BRIGHT_RED}
warning_4bit :: ANSI_4Bit{fg = .FG_BRIGHT_YELLOW}
heading_4bit :: ANSI_4Bit{fg = .FG_BRIGHT_WHITE, bg = .BG_BRIGHT_MAGENTA, att = {.UNDERLINE, .ITALIC}}

nocolor_8bit :: ANSI_8Bit{}
hello_8bit   :: ANSI_8Bit{fg = 118}
world_8bit   :: ANSI_8Bit{fg = 51}
error_8bit   :: ANSI_8Bit{fg = 196}
warning_8bit :: ANSI_8Bit{fg = 226}
heading_8bit :: ANSI_8Bit{fg = 15, bg = 207, att = {.UNDERLINE, .ITALIC}}

nocolor_24bit :: ANSI_24Bit{}
hello_24bit   :: ANSI_24Bit{fg = {20, 200, 20}}
world_24bit   :: ANSI_24Bit{fg = {20, 150, 150}}
error_24bit   :: ANSI_24Bit{fg = {240, 75, 75}}
warning_24bit :: ANSI_24Bit{fg = {220, 230, 20}}
heading_24bit :: ANSI_24Bit{fg = {255, 255, 255}, bg = {224, 0, 133}, att = {.UNDERLINE, .ITALIC}}

// +build !import
main :: proc() {

	fmt.println("\nTesting 3bit color printing\n")
	printflnc(nocolor_3bit, "%s", "This tests no color. i.e. nil")
	printfc(hello_3bit, "%-15s", "hellope")
	printflnc(world_3bit, "%s", "world!")
	printflnc(error_3bit, "%s", "This test what I might use for an error.")
	printflnc(warning_3bit, "%s", "This tests what I might use for a warning")
	printflnc(heading_3bit, "%s", "Testing a sudo heading with fg and bg and 2 attributes?")

	fmt.println("\nTesting 4bit color printing\n")
	printflnc(nocolor_4bit, "%s", "This tests no color. i.e. nil")
	printfc(hello_4bit, "%-15s", "hellope")
	printflnc(world_4bit, "%s", "world!")
	printflnc(error_4bit, "%s", "This test what I might use for an error.")
	printflnc(warning_4bit, "%s", "This tests what I might use for a warning")
	printflnc(heading_4bit, "%s", "Testing a sudo heading with fg and bg and 2 attributes?")

	fmt.println("\nTesting 8bit color printing\n")
	printflnc(nocolor_8bit, "%s", "This tests no color. i.e. nil")
	printfc(hello_8bit, "%-15s", "hellope")
	printflnc(world_8bit, "%s", "world!")
	printflnc(error_8bit, "%s", "This test what I might use for an error.")
	printflnc(warning_8bit, "%s", "This tests what I might use for a warning")
	printflnc(heading_8bit, "%s", "Testing a sudo heading with fg and bg and 2 attributes?")

	fmt.println("\nTesting 24bit color printing\n")
	printflnc(nocolor_24bit, "%s", "This tests no color. i.e. nil")
	printfc(hello_24bit, "%-15s", "hellope")
	printflnc(world_24bit, "%s", "world!")
	printflnc(error_24bit, "%s", "This test what I might use for an error.")
	printflnc(warning_24bit, "%s", "This tests what I might use for a warning")
	printflnc(heading_24bit, "%s", "Testing a sudo heading with fg and bg and 2 attributes?")

	fmt.println()

	// if running in a loop or executing often in a long running program,
	// periodically clear the context.temp_allocator either in a loop,
	// or when appropriate.
	free_all(context.temp_allocator)
}
