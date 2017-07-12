----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:06:27 01/28/2017 
-- Design Name: 
-- Module Name:    encrypter - Behavioral 
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


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use STD.textio.all;                     -- basic I/O
use IEEE.std_logic_textio.all;          -- I/O for logic types


-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity encrypter is
    Port ( clk : in  STD_LOGIC;
			  reset : in STD_LOGIC;
           plaintext : in  STD_LOGIC_VECTOR (63 downto 0);
           start : in  STD_LOGIC;
           ciphertext : out  STD_LOGIC_VECTOR (63 downto 0) := x"0000000000000000";
           done : out  STD_LOGIC := '1');
end encrypter;

architecture Behavioral of encrypter is
signal i: integer range -2 to 97 :=-2;
--shared variable beg: integer := 0;
signal v0: unsigned (31 downto 0):=x"00000000";
signal t1: unsigned(31 downto 0);
signal t2: unsigned(31 downto 0);
signal v1: unsigned (31 downto 0):=x"00000000";
signal sum: unsigned (31 downto 0):=x"00000000";
--shared variable i: integer :=-2;
constant delta: unsigned (31 downto 0):=x"9e3779b9";
constant key: unsigned (127 downto 0):=x"ff0f745743fd99f775f8c48f2927c18c";
constant k0: unsigned (31 downto 0):=key(31 downto 0);
constant k1: unsigned (31 downto 0):=key(63 downto 32);
constant k2: unsigned (31 downto 0):=key(95 downto 64);
constant k3: unsigned (31 downto 0):=key(127 downto 96);
--shared variable flag:integer:=0;

begin

--process(clk )
--begin
--if(clk'event and clk='1')then
--		t1:=unsigned(plaintext(31 downto 0));
--		t2:=unsigned(plaintext(63 downto 32));
--end if;
--end process;
--
--
--
process(clk)
--variable my_line : line;
variable flag:std_logic := '0';
variable beg:std_logic:= '0';
begin

if(rising_edge(clk))then
	if(reset='1') then
		flag:='0';
		v0<=x"00000000";
		v1<=x"00000000";
	--	k0<=x"00000000";
	--	k1<=x"00000000";
	--	k2<=x"00000000"; 
	--	k3<=x"00000000";
		sum<=x"00000000";
		i<=-2;

		done<='1';
		ciphertext<=x"0000000000000000";	
		beg :='0';

	else
		if(((start='1') or beg = '1') ) then 
			flag:='1';
			beg := '1';
			if(i=-2) then
				i<=-1;
	--			k0<=key(31 downto 0);
	--			k1<=key(63 downto 32);
	--			k2<=key(95 downto 64);
	--			k3<=key(127 downto 96);
--				write(my_line, string'("Hello World1"));   -- formatting
--				writeline(output, my_line);               -- write to "output"	 
				done <= '0';
				t1<=unsigned(plaintext(31 downto 0));
				t2<=unsigned(plaintext(63 downto 32));
			elsif(i=-1) then
				v0<=t1;
				v1<=t2;
				i<=0;
			elsif(i<96 and i>=0 ) then
				if((i mod 3)=0) then
					sum <= sum + delta;
				elsif((i mod 3)=1) then
					v0<= v0 + ((shift_left(v1, 4) + k0) XOR (v1 + sum) XOR (shift_right(v1,  5) + k1));
				else
					v1<= v1 + ((shift_left(v0, 4) + k2) XOR (v0 + sum) XOR (shift_right(v0,  5) + k3));
				end if;
				i<=i+1;
--						write(my_line, string'("Hello World2"));   -- formatting
--				writeline(output, my_line);               -- write to "output"	 
			else
				ciphertext(31 downto 0)<=std_logic_vector(v0);
				ciphertext(63 downto 32)<=std_logic_vector(v1);
				done<='1';
				beg :='0';
--				write(my_line, string'("Hello World3"));   -- formatting
--				writeline(output, my_line);               -- write to "output"	 
			end if;
		elsif(flag='0' )then
			ciphertext<=x"0000000000000000";
		end if;
	end if;
end if;	
end process;
end Behavioral;