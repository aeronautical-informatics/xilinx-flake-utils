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

entity LED_Driver is
    Port    (
                LED_1_i : in    std_logic;
                LED_1_o : out   std_logic   := '0';
                LED_2_i : in    std_logic;
                LED_2_o : out   std_logic   := '0'
            );
end LED_Driver;

architecture Behavioral of LED_Driver is
begin
    
    LED_1_o <= LED_1_i;
    LED_2_o <= LED_2_i;

end Behavioral;