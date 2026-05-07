set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]
set jtag_dir  [file join $repo_root "Releases" "JTAG"]

set ps7_init  [file join $jtag_dir "ps7_init.tcl"]
set bitstream [file join $jtag_dir "riscv_cpu_zynq_pl.bit"]
set app_elf   [file join $jtag_dir "app.elf"]

foreach path [list $ps7_init $bitstream $app_elf] {
    if {![file exists $path]} {
        error "Required release asset not found: $path"
    }
}

connect

targets -set -filter {name =~ "ARM Cortex-A9*#0"}
stop
rst -system
after 1000

targets -set -filter {name =~ "ARM Cortex-A9*#0"}
source $ps7_init
ps7_init

targets -set -filter {name =~ "xc7z020"}
fpga $bitstream

targets -set -filter {name =~ "ARM Cortex-A9*#0"}
ps7_post_config
dow $app_elf
con
