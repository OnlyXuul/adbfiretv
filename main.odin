package adbfiretv

import "core:os"
import "core:os/os2"
import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:net"
import "core:time"

import "ansi_color"

/******************************************************************************
 * Process execution data and procedures
 ******************************************************************************/

// Process data
Process :: struct {
	allocator: runtime.Allocator,
	state:     os2.Process_State,
	stdout:    []byte,
	stderr:    []byte,
	error:     os2.Error,
}

// process_exec does not free `stdout` and `stderr` slices before an error
// Make sure to call `delete` on these slices.
delete_process :: proc(p: ^Process) {
	delete(p.stderr)
	delete(p.stdout)
	free_all(p.allocator)
}

// execute command - print error if there is one
exec_command :: proc(p: ^Process, command: os2.Process_Desc) {
	p.state, p.stdout, p.stderr, p.error = os2.process_exec(command, p.allocator)
	p.stdout = trim_stdout_newline(p.stdout)
	p.stderr = trim_stdout_newline(p.stderr)
	// print an error only if there was one
	if len(p.stderr) != 0 {
		printfcln(ERROR, "%s", p.stderr)
	}
}

// trim newline from returned command data
trim_stdout_newline :: proc(s: []u8) -> []u8 {
	if len(s) != 0 && s[len(s)-1] == '\n' {
		return s[:len(s)-1]
	}
	return s
}

/******************************************************************************
 * adb connect
 ******************************************************************************/

// check for command line paramter and then connect
adb_connect :: proc(adb: ^os2.Process_Desc, p: ^Process) -> (success: bool) {
	using strings

	for arg, idx in os.args {

		// look for cli command with ip
		if (arg == "-c" || arg == "-connect") && idx + 1 < len(os.args) {
			_, ip_ok := net.parse_ip4_address(os.args[idx+1])

			// invalid ip error
			if !ip_ok {
				printfcln(ERROR, "%s %s", "Invalid IP address:", os.args[idx+1])
				return false
			}

			// connect with valid ip
			adb.command = { "adb","connect", os.args[idx+1] }
			exec_command(p, adb^)

			// os process errors
			if !p.state.success {
				printfcln(ERROR, "%v", p.state)
				printfcln(ERROR, "%v", os2.error_string(p.error))
				return false
			}

			// adb connection status message
			if starts_with(string(p.stdout), "connected") || starts_with(string(p.stdout), "already connected") {
				// success
				printfcln(STATUS, "%s", p.stdout)
				return true
			}
			else {
				// failed
				printfcln(ERROR, "%s", p.stdout)
				return false
			}
			break
		}
	}

	// no connection command found
	printfcln(ERROR, "%s", "-c <address> command required")
	return false
}

/******************************************************************************
 * Output parsing procedures
 ******************************************************************************/

parse_package_size :: proc(data: []byte, pkg: string) {
	using strings

	assert(len(data) > 0)
	lines := split(string(data), "\n")
	defer delete(lines)
	package_names: []string
	defer delete(package_names)
	app_sizes: []string
	defer delete(app_sizes)
	app_data_sizes: []string
	defer delete(app_data_sizes)
	cache_sizes: []string
	defer delete(cache_sizes)

	// Get the 3 data sets for packages
	for &line, l_idx in lines {
		line_slice := split(line, ":")
		defer delete(line_slice)

		if len(line_slice) == 2 {

			trim_line :: proc(s: ^string) {
				s^, _ = remove_all(s^, "\"")
				s^, _ = remove_all(s^, "[")
				s^, _ = remove_all(s^, "]")
			}

			switch line_slice[0] {
				case "Package Names":  trim_line(&line_slice[1]); package_names = split(line_slice[1], ",")
				case "App Sizes":      trim_line(&line_slice[1]); app_sizes = split(line_slice[1], ",")
				case "App Data Sizes": trim_line(&line_slice[1]); app_data_sizes = split(line_slice[1], ",")
				case "Cache Sizes":    trim_line(&line_slice[1]); cache_sizes = split(line_slice[1], ",")
			}

			plength := len(package_names)
			if len(app_sizes) == plength && len(app_data_sizes) == plength && len(cache_sizes) == plength {
				for p, p_idx in package_names {
					if p == pkg {
						printfcln(INFO, "%s %s", "Disk Usage of:", pkg)
						app_size,   as_ok := strconv.parse_f64(app_sizes[p_idx])
						data_size,  ds_ok := strconv.parse_f64(app_data_sizes[p_idx])
						cache_size, cs_ok := strconv.parse_f64(cache_sizes[p_idx])
						if as_ok && ds_ok && cs_ok {
							printfc(LABEL, "%-12s", "App Size:")
							printfcln(OUTPUT, "%f%s%s%f%s", app_size / 1048576, "MB ", "(", app_size / 1048576 / 1024, "GB)")
							printfc(LABEL, "%-12s", "Data Size:")
							printfcln(OUTPUT, "%f%s%s%f%s", data_size / 1048576, "MB ", "(", data_size / 1048576 / 1024, "GB)")
							printfc(LABEL, "%-12s", "Cache Size:")
							printfcln(OUTPUT, "%f%s%s%f%s", cache_size / 1048576, "MB ", "(", cache_size / 1048576 / 1024, "GB)")
							break
						}
					}
				}
			}
		}
	}
}

parse_system_data_sizes :: proc(data: []byte) {
	using strings

	assert(len(data) > 0)

	buf: [16]byte
	lines := split(string(data), "\n")
	defer delete(lines)

	{ // First two lines - Latency and Recent
		printfcln(INFO, "%s", "Disk Speed:")
		for &line, l_idx in lines {
			line_slice := split(line, ":")
			defer delete(line_slice)
			if line_slice[0] == "Latency" && len(line_slice) == 2 {
				printfc(LABEL, "%s%-1s", line_slice[0], ":")
				printfcln(OUTPUT, "%s", line_slice[1])
			}
			if starts_with(line_slice[0], "Recent Disk Write Speed (kB/s) = ") {
				line_slice[0], _ = remove(line_slice[0], "Recent Disk Write Speed (kB/s) = ", 1)
				printfc(LABEL, "%s ", "Recent Disk Write Speed (kB/s):")
				printfcln(OUTPUT, "%s", line_slice[0])
			}
		}
	}

	{ // System data usage - defer delete(line_slice) happens at end of this context
		printfcln(INFO, "%s", "System Disk Usage:")
		system_data: [dynamic][]string
		defer delete(system_data)
		format_width := make([dynamic]int, 8, 8)
			defer delete(format_width)
			line_slice: []string
			defer delete(line_slice)

			for &line, l_idx in lines {
				line_slice = split(line, " ")
				if	line_slice[0] == "Data-Free:"   ||
					line_slice[0] == "Cache-Free:"  ||
					line_slice[0] == "System-Free:" {
						for &word, w_idx in line_slice {
							if contains(word, "K") {
								word, _ = remove_all(word, "K")
								num, ok := strconv.parse_f64(word)
								if ok {
									MBs := trim_prefix(clone(strconv.write_float(buf[:], num / 1024, 'f', 2, 64)), "+")
									GBs := trim_prefix(clone(strconv.write_float(buf[:], num / 1024 / 1024, 'f', 2, 64)), "+")
									line_slice[w_idx] = concatenate({MBs,	"MB ", "(",	GBs, "GB)"})
								}
							}
							if w_idx > len(format_width) - 1 { append(&format_width, len(word)) }
							format_width[w_idx] = len(word) > format_width[w_idx] ? len(word) : format_width[w_idx]
						}
						append(&system_data, line_slice)
					}
			}
			// formated output
			for line in system_data {
				for word, w_idx in line {
					if w_idx == 0 { printfc(LABEL, "%-*s", format_width[w_idx] + 1, word)	}
					else { printfc(OUTPUT, "%-*s", format_width[w_idx] + 1, word) }
				}
				fmt.println()
			}
	}

	{ // disk usage break down by category
		printfcln(INFO, "%s", "Categorical Disk Usage:")
		category_data: [dynamic][]string
		defer delete(category_data)
		format_width: [2]int
			line_slice: []string
			defer delete(line_slice)
			for &line, l_idx in lines {
				line_slice = split(line, ":")
				if line_slice[0] == "App Size"      ||
					line_slice[0] == "App Data Size"  ||
					line_slice[0] == "App Cache Size" ||
					line_slice[0] == "Photos Size"    ||
					line_slice[0] == "Videos Size"    ||
					line_slice[0] == "Audio Size"     ||
					line_slice[0] == "Downloads Size" ||
					line_slice[0] == "System Size"    ||
					line_slice[0] == "Other Size"	    {
						line_slice[0] = concatenate({line_slice[0], ":"})
						line_slice[1] = trim_space(line_slice[1])
						num, ok := strconv.parse_f64(line_slice[1])
						if ok {
							MBs := trim_prefix(clone(strconv.write_float(buf[:], num / 1048576, 'f', 2, 64)), "+")
							GBs := trim_prefix(clone(strconv.write_float(buf[:], num / 1048576 / 1024, 'f', 2, 64)), "+")
							line_slice[1] = concatenate({MBs,	"MB ", "(",	GBs, "GB)"})
						}
						format_width[0] = len(line_slice[0]) > format_width[0] ? len(line_slice[0]) : format_width[0]
							format_width[1] = len(line_slice[1]) > format_width[1] ? len(line_slice[1]) : format_width[1]
								append(&category_data, line_slice)
					}
			}
			// formated output
			for line in category_data {
				for word, w_idx in line {
					if w_idx == 0 { printfc(LABEL, "%-*s", format_width[w_idx] + 1, word)	}
					else { printfc(OUTPUT, "%-*s", format_width[w_idx] + 1, word) }
				}
				fmt.println()
			}
	}
}

/******************************************************************************
 * Help procedures
 ******************************************************************************/

// do you need help?
check_for_help :: proc() -> (help: bool) {
	using strings

	no_color_argument := is_no_color_argument()

	// no arguments provided or only -nc provided
	if len(os.args) <= 1 || no_color_argument && len(os.args) <= 2 {
		return true
	}
	// only care if -h is the first argument, so -h can be used with -d argument for dumpsys
	// or second argument if -nc is used first
	if (os.args[1] == "-h" || os.args[1] == "--help") ||
		(no_color_argument && (os.args[2] == "-h" || os.args[2] == "--help")) {
		help = true
	}
	return
}

// max text length - split on word
split_max_width :: proc(width: int, text: string) -> (output: [dynamic]string) {
	using strings

	text_words := split(text, " ")

	if len(text_words) != 0 {
		append(&output, text_words[0])
	}
	else {
		return
	}

	for i := 1; i < len(text_words); i += 1 {
		if len(text_words[i]) + len(output[len(output)-1]) + 1 <= width {
			output[len(output)-1] = concatenate({output[len(output)-1], " ", text_words[i]})
		}
		else {
			append(&output, text_words[i])
		}
	}

	return
}

// usage
print_usage :: proc() {
	using time

	printfc(INFO, "%-14s", ODIN_BUILD_PROJECT_NAME + " by:")
	printfcln(ERROR, "%s", "xuul the terror dog")

	buf: [MIN_YYYY_DATE_LEN]u8
	printfc(LABEL, "%-14s", "Compile Date:")
	printfcln(OUTPUT, "%s", to_string_yyyy_mm_dd(now(), buf[:]))
	printfc(LABEL, "%-14s", "Odin Version:")
	printfcln(OUTPUT, "%s\n", ODIN_VERSION)

	printfcln(INFO, "%s", "Usage: adbfiretv [options] <required>\n")

	// use one place to set up column formating
	max_width := 86
	col: [4]int = {4, 13, 19, 0}
	col[3] = col[0] + col[1] + col[2]

	// split string based on max width of ouput to terminal
	description: [dynamic]string
	defer delete(description)

	printfcln(LABEL, "%-*s%-*s%s", col[0] + col[1], "[Options]", col[2], "<Arguments>", "Description")

	printfc(STATUS, "%-*s", col[0], "-h"); printfc(STATUS, "%-*s", col[1], "-help")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Prints this help message if it is the first argument.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-nc"); printfc(STATUS, "%-13s", "-nocolor")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Disables colored output. "+
		"Removes ANSI color codes to make scripting easier. "+
		"Color is automatically disabled if it is disabled in the terminal.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-v"); printfc(STATUS, "%-13s", "-version")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Outputs Android Version, FireOS Version, Device Model, and Serial Number.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-r"); printfc(STATUS, "%-13s", "-running")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Outputs list of running (3rd Party) user applications.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}


	printfc(STATUS, "%-*s", col[0] + col[1], "-wake")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Attempts to wake the device. "+
		"Only works if device is not asleep for long.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0] + col[1], "-sleep")
	printfc(INFO, "%-*s", col[2], "<none>")
	description = split_max_width(max_width - col[3],
		"Attempts to put the device into sleep mode. "+
		"Recommend using this as the last command if using mulitples.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-d"); printfc(STATUS, "%-13s", "-dumpsys")
	printfc(INFO, "%-*s", col[2], "<see description>")
	description = split_max_width(max_width - col[3],
		"Gets information from the device database. "+
		"A typical argument may be 'power' or 'activity'. "+
		"Place any argument that has spaces in quotes. "+
		"Use '--help' as an argument to get dumpsys help.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-k"); printfc(STATUS, "%-13s", "-kill")
	printfc(INFO, "%-*s", col[2], "<all | package>")
	description = split_max_width(max_width - col[3],
		"Stops the specified package name. "+
		"If 'all' is provided, all (3rd Party) user packages are stopped.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-l"); printfc(STATUS, "%-13s", "-launch")
	printfc(INFO, "%-*s", col[2], "<package>")
	description = split_max_width(max_width - col[3],
		"Starts the specified package name or brings it to the front if already running. "+
		"Kodi supported. "+
		"Others may or may not be depending if they require a unique 'Starting Intent'. "+
		"Support may be added upon request.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-m"); printfc(STATUS, "%-13s", "-memoryusage")
	printfc(INFO, "%-*s", col[2], "<package>")
	description = split_max_width(max_width - col[3],
		"Outputs current memory usage of specified package name.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-p"); printfc(STATUS, "%-13s", "-packages")
	printfc(INFO, "%-*s", col[2], "<user | system>")
	description = split_max_width(max_width - col[3],
		"Lists (3rd Party) 'user' installed packages or (FireOS) 'system' installed packages.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0], "-s"); printfc(STATUS, "%-13s", "-space")
	printfc(INFO, "%-*s", col[2], "<system | package>")
	description = split_max_width(max_width - col[3],
		"Outputs disk space usage for either 'system' or specified package name.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0] + col[1], "-clearcache");
	printfc(INFO, "%-*s", col[2], "<package>")
	description = split_max_width(max_width - col[3],
		"Clears cache for the specified package name. "+
		"Take cear with what packages you clear. "+
		"Some apps may revert to new install configuration like Kodi does.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}

	printfc(STATUS, "%-*s", col[0] + col[1], "-cleardata");
	printfc(INFO, "%-*s", col[2], "<package>")
	description = split_max_width(max_width - col[3],
		"Clears data for the specified package name. "+
		"Take cear with what packages you clear. "+
		"Some apps may revert to new install configuration like Kodi does.")
	for d, i in description {
		if i == 0 { printfcln(OUTPUT, "%s", d) }
		else { printfcln(OUTPUT, "%*s", col[3] + len(d), d) }
	}
}

/******************************************************************************
 * Main driver
 * Also color formating globals for printing
 ******************************************************************************/

ANSI_3Bit :: ansi_color.ANSI_3Bit
printfc   :: ansi_color.printfc
printfcln :: ansi_color.printfcln

LABEL  := ANSI_3Bit{fg = .FG_MAGENTA}
INFO   := ANSI_3Bit{fg = .FG_YELLOW}
STATUS := ANSI_3Bit{fg = .FG_GREEN}
OUTPUT := ANSI_3Bit{fg = .FG_BLUE}
ERROR  := ANSI_3Bit{fg = .FG_RED}

is_no_color_argument :: proc() -> (ok: bool) {
	using strings
	if contains(join(os.args, " "), "-nc") || contains(join(os.args, " "), "-nocolor") {
		LABEL  = {}
		INFO   = {}
		STATUS = {}
		OUTPUT = {}
		ERROR  = {}
		return true
	}
	return false
}

main :: proc() {
	using strings

	// check for no color argument
	is_no_color_argument()

	// check for help argument
	help := check_for_help()
	if help {	print_usage(); os.exit(0)	}

	// create process struct
	p: Process; defer delete_process(&p)
	adb: os2.Process_Desc

	// connect
	connected := adb_connect(&adb, &p)

	if connected {
		// process arguments
		for arg, idx in os.args {
			switch arg {
			// arguments with no parameters
			case "-r", "-running":
				adb.command = { "adb", "shell", "pm", "list", "packages", "-3" }
				exec_command(&p, adb)
				packages, p_ok := remove(string(p.stdout), "package:", -1)
				adb.command = {"adb", "shell", "ps", "-o", "ARGS=CMD"}
				exec_command(&p, adb)
				running_packages := split_lines(string(p.stdout))
				printfcln(INFO, "%s", "Running User Installed (3rd Party) Packages:")
				for running in running_packages {
					if contains(packages, running) {
						printfcln(OUTPUT, "%s", running)
					}
				}
			case "-wake":
				adb.command = {"adb", "shell", "input", "keyevent", "KEYCODE_WAKE"}
				exec_command(&p, adb)
				printfcln(INFO, "%s", "Attempting to wake device ...")
			case "-sleep":
				adb.command = {"adb", "shell", "input", "keyevent", "KEYCODE_SLEEP"}
				exec_command(&p, adb)
				printfcln(INFO, "%s", "Attempting to put device to sleep ...")
			case "-v", "-version":
				adb.command = {"adb", "shell", "getprop", "ro.build.version.release"}
				exec_command(&p, adb)
				printfc(LABEL, "%-17s", "Android Version:")
				printfcln(OUTPUT, "%s", p.stdout)
				adb.command = {"adb", "shell", "getprop", "ro.build.version.name"}
				exec_command(&p, adb)
				printfc(LABEL, "%-17s", "FireOS Version:")
				printfcln(OUTPUT, "%s", p.stdout)
				adb.command = {"adb", "shell", "getprop", "ro.product.oemmodel"}
				exec_command(&p, adb)
				printfc(LABEL, "%-17s", "Device Model:")
				printfcln(OUTPUT, "%s", p.stdout)
				adb.command = {"adb", "shell", "getprop", "ro.serialno"}
				exec_command(&p, adb)
				printfc(LABEL, "%-17s", "Serial No:")
				printfcln(OUTPUT, "%s", p.stdout)
			// arguments containing 1 parameter
			case "-l", "launch":
				if idx + 1 < len(os.args) {
					if os.args[idx+1] == "org.xbmc.kodi" {
						adb.command = {"adb", "shell", "am", "start", "org.xbmc.kodi/.Splash"}
					}
					else {
						adb.command = {"adb", "shell", "am", "start", os.args[idx+1]}
					}
					exec_command(&p, adb)
					printfcln(INFO, "%s", p.stdout)
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],".")
				}
			case "-p", "-packages":
				if idx + 1 < len(os.args) {
					if os.args[idx+1] == "user" {
						adb.command = {"adb", "shell", "pm", "list", "packages", "-3"}
						exec_command(&p, adb)
						packages, p_ok := remove(string(p.stdout), "package:", -1)
						printfcln(INFO, "%s", "User Installed (3rd Party) Packages:")
						printfcln(OUTPUT, "%s", packages)
					}
					else if os.args[idx+1] == "system" {
						adb.command = {"adb", "shell", "pm", "list", "packages", "-s"}
						exec_command(&p, adb)
						packages, p_ok := remove(string(p.stdout), "package:", -1)
						printfcln(INFO, "%s", "System Installed (FireOS) Packages:")
						printfcln(OUTPUT, "%s", packages)
					}
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". 'user' or 'system'")
				}
			case "-d", "-dumpsys":
				if idx + 1 < len(os.args) {
					// can also do "--help" and other commands with this only if they are in quotes
					adb.command = {"adb", "shell", "-x", "dumpsys", os.args[idx+1]}
					exec_command(&p, adb)
					printfcln(OUTPUT, "%s", p.stdout)
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". See -help for more info.")
				}
			case "-k", "-kill":
				if idx + 1 < len(os.args) {
					if os.args[idx+1] == "all" {
						adb.command = { "adb", "shell", "pm", "list", "packages", "-3" }
						exec_command(&p, adb)
						packages, p_ok := remove(string(p.stdout), "package:", -1)
						adb.command = {"adb", "shell", "ps", "-o", "ARGS=CMD"}
						exec_command(&p, adb)
						running_packages := split_lines(string(p.stdout))
						for running in running_packages {
							if contains(packages, running) {
								adb.command = {"adb", "shell", "am", "force-stop", running}
								printfcln(INFO, "%s %s", "Killing:", running)
								exec_command(&p, adb)
							}
						}
					}
					else {
						adb.command = {"adb", "shell", "am", "force-stop", os.args[idx+1]}
						printfcln(INFO, "%s %s", "Attempting to kill:", os.args[idx+1])
						exec_command(&p, adb)
					}
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". Either 'all' or package name.")
				}
			case "-clearcache":
				if idx + 1 < len(os.args) {
					adb.command = {"adb", "shell", "pm", "clear", "--cache-only", os.args[idx+1]}
					printfcln(INFO, "%s %s", "Attempting to clear cache of:", os.args[idx+1])
					exec_command(&p, adb)
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". i.e. package name.")
				}
			case "-cleardata":
				if idx + 1 < len(os.args) {
					adb.command = {"adb", "shell", "pm", "clear", os.args[idx+1]}
					printfcln(INFO, "%s %s", "Attempting to clear data of:", os.args[idx+1])
					exec_command(&p, adb)
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". i.e. package name.")
				}
			case "-m", "memoryusage":
				if idx + 1 < len(os.args) {
					adb.command = {"adb", "shell", "dumpsys", "meminfo", os.args[idx+1]}
					exec_command(&p, adb)
					if strings.starts_with(string(p.stdout), "No process found") {
						printfcln(ERROR, "%s", p.stdout)
					}
					else {
						printfcln(INFO, "%s %s", "Memory Usage:", os.args[idx+1])
						printfcln(OUTPUT, "%s", p.stdout)
					}
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". i.e. package name.")
				}
			case "-s", "-space":
				if idx + 1 < len(os.args) {
					// note to self for parsing - if it's in KB it's specified, otherwise all else in Bytes
					if os.args[idx+1] == "system" {
						adb.command = {"adb", "shell", "dumpsys", "diskstats"}
						exec_command(&p, adb)
						parse_system_data_sizes(p.stdout)
					}
					else {
						adb.command = { "adb", "shell", "pm", "list", "packages", "-3" }
						exec_command(&p, adb)
						user_packages, up_ok := remove(string(p.stdout), "package:", -1)
						adb.command = {"adb", "shell", "pm", "list", "packages", "-s"}
						exec_command(&p, adb)
						system_packages, sp_ok := remove(string(p.stdout), "package:", -1)
						if contains(string(user_packages), os.args[idx+1]) || contains(string(system_packages), os.args[idx+1]) {
							adb.command = {"adb", "shell", "dumpsys", "diskstats"}
							exec_command(&p, adb)
							parse_package_size(p.stdout, os.args[idx+1])
						}
						else {
							printfcln(ERROR, "%s %s", "Could not find:", os.args[idx+1])
						}
					}
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],". 'system' or package name")
				}
			case "-vol":
				// experimental
				if idx + 1 < len(os.args) {
					input := split(os.args[idx+1], ":")
					volume, max_retry: uint
					vol_ok, max_ok: bool

					volume, vol_ok = strconv.parse_uint(input[0])
					vol_ok = volume <= 100

					if len(input) == 2 {
						max_retry, max_ok = strconv.parse_uint(input[1])
					}
					max_retry = max_retry <= 50 ? max_retry : 0

					if vol_ok { process_volume_change(volume, max_retry, &p, &adb) }
				}
				else {
					printfcln(ERROR, "%s%s%s", "Must provide an argument with ", os.args[idx],".")
				}
			}
			free_all(context.allocator)
		}
	}

	// disconnect if connected
	if connected {
	adb.command = { "adb","disconnect" }
	exec_command(&p, adb)
	printfcln(STATUS, "%s", p.stdout)
	}
}

// experimental volume changer
process_volume_change :: proc(volume: uint, max_retry: uint, p: ^Process, adb: ^os2.Process_Desc) {
	using strings

	//adb.command = {"adb", "shell", "getprop", "ro.build.version.release"}
	//version, ver_ok := strconv.parse_u64(string(p.stdout))
	//media := version <= 10 ? "media" : "cmd media_session"

	volume_is_correct: bool
	buf: [64]byte
	vol := strconv.write_uint(buf[:], u64(volume), 10)

	for i := uint(0); i <= max_retry && !volume_is_correct; i += 1 {
		adb.command = { "adb", "shell", "media", "volume", "--set", vol }
		exec_command(p, adb^)
		adb.command = { "adb", "shell", "media", "volume", "--get" }
		exec_command(p, adb^)
		vol_service_output := split(string(p.stdout), "\n")
		if len(vol_service_output) >= 3 {
			set_volume := split(vol_service_output[2], " ")
			if len(set_volume) >= 4 {
				num, _ := strconv.parse_int(set_volume[3])
				if uint(num) == volume {
					volume_is_correct = true
					volume_is, _ := remove(vol_service_output[2], "[v] ", 1)
					printfcln(STATUS, "%s", volume_is)
				}
				else {
					volume_is, _ := remove(vol_service_output[2], "[v] ", 1)
					printfc(STATUS, "%s - ", volume_is)
					printfcln(INFO, "%s", "retrying")
				}
			}
		}
	}
}
