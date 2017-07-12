----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:00:01 01/25/2017 
-- Design Name: 
-- Module Name:    read_multiple_data_bytes - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all; 

entity read_multiple_data_bytes is
    Port ( clk : in  STD_LOGIC;
           data_in : in  STD_LOGIC_VECTOR (7 downto 0);
			  reset : in STD_LOGIC;
           next_data : in  STD_LOGIC;
           data_read : out  STD_LOGIC_VECTOR (63 downto 0):=x"0000000000000000";
			  bytes_read: out STD_LOGIC_VECTOR(3 downto 0):="0000");
end read_multiple_data_bytes;

architecture Behavioral of read_multiple_data_bytes is
signal i1 : integer range 0 to 8 := 0 ;
--signal byte_read : integer range 0 to 8 := 0 ;
--signal i2 : integer range 0 to 65 := 7 ;
begin

process(clk)
--variable i1:unsigned(7 downto 0):="00000000"; 
--variable i2:unsigned(7 downto 0):="00000111";
--variable i1:integer:=0; 
--variable i2:integer:=7;
--signal i01 : integer range 0 to 65 := 0 ;
--signal i02 : integer range 0 to 65 := 7 ;
--signal COUNT : integer range 0 to 15;

variable flag:std_logic := '1';

begin
	
	if(rising_edge(clk))then
		if(reset='1')then
--			i2:="00000111";
--			i1:="00000000";
--			i2<=7;
			i1<=0;
			bytes_read<="0000";
			data_read<=x"0000000000000000";
		elsif(i1<8)then
	  
			if(next_data ='0')then
				flag := '1';
			else
				if(flag = '1')then
					data_read((i1+1)*8 - 1 downto i1*8)<=data_in;
			--		data_out<=data_in(i2 downto i1);
--					i2 <= i2 + 8;
					i1 <= i1 + 1;
					bytes_read<=std_logic_vector(to_unsigned(i1+1,4));	
					flag := '0';
				end if;
			end if;
		end if;
--	elsif(clk'event and clk='1' and i2<64 and next_data='0')then
--		flag  :='1';
	end if;
	
--	wait on next_data,reset;

end process;


end Behavioral;