----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/14/2023 10:34:49 AM
-- Design Name: 
-- Module Name: LED_Driver - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LED_Driver_FCC_Monitoring is
    Port    (
                LED21_i : in    std_logic;
                LED21_o : out   std_logic   := '0';
                LED22_i : in    std_logic;
                LED22_o : out   std_logic   := '0'
            );
end LED_Driver_FCC_Monitoring;

architecture Behavioral of LED_Driver_FCC_Monitoring is
begin
    
    LED21_o <= LED21_i;
    LED22_o <= LED22_i;

end Behavioral;