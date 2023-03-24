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

entity LED_Driver_Lane_Commanding is
    Port    (
                LED11_i : in    std_logic;
                LED11_o : out   std_logic   := '0';
                LED12_i : in    std_logic;
                LED12_o : out   std_logic   := '0'
            );
end LED_Driver_Lane_Commanding;

architecture Behavioral of LED_Driver_Lane_Commanding is
begin
    
    LED11_o <= LED11_i;
    LED12_o <= LED12_i;

end Behavioral;