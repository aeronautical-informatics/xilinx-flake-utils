#!/usr/bin/env xsct

# ta = APU | A53
proc reset_apu { } {
        rst -cores
}

# ta = RPU | R5
proc clear_rpu_reset {} {
        rst -cores
}

# ta = RPU | R5
proc enable_split_mode {} {
        mwr 0xff9a0000 0x208
}

# ta = A53
proc enable_a32_mode { cpunr } {
        if { $cpunr > 3 } { error "invalid cpu number" }
        set val [mrd -force -value 0xfd5c0020]
        mwr -force 0xfd5c0020 [expr {$val & ~(1 << $cpunr)}]
}

proc psu_protection {} {
        # dummy proc for older designs
}

# ta = PSU | APU | RPU
proc disable_pmu_gate {} {
        set status [mrd -force -value 0xFFCA0038]
        set status [expr $status | 0x1C0]
        mwr -force 0xFFCA0038 $status
}

