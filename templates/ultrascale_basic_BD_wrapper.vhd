--Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2019.2.1 (lin64) Build 2729669 Thu Dec  5 04:48:12 MST 2019
--Date        : Wed Oct  5 14:52:44 2022
--Host        : Ubuntu-18 running 64-bit Ubuntu 18.04.6 LTS
--Command     : generate_target ultrascale_basic_BD_wrapper.bd
--Design      : ultrascale_basic_BD_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ultrascale_basic_BD_wrapper is
end ultrascale_basic_BD_wrapper;

architecture STRUCTURE of ultrascale_basic_BD_wrapper is
  component ultrascale_basic_BD is
  end component ultrascale_basic_BD;
begin
ultrascale_basic_BD_i: component ultrascale_basic_BD
 ;
end STRUCTURE;
