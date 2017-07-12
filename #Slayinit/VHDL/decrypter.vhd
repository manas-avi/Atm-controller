----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:53:10 01/28/2017 
-- Design Name: 
-- Module Name:    decrypter - Behavioral 
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity decrypter is
    Port ( clk : in  STD_LOGIC;
           ciphertext : in  STD_LOGIC_VECTOR (63 downto 0);
           start : in  STD_LOGIC;
			  reset : in STD_LOGIC;
           plaintext : out  STD_LOGIC_VECTOR (31 downto 0) :=x"00000000";
           done : out  STD_LOGIC := '1');
end decrypter;

architecture Behavioral of decrypter is

signal v0: unsigned (31 downto 0):=x"00000000";
--shared variable beg: integer := 0;
signal t1: unsigned(31 downto 0);
signal t2: unsigned(31 downto 0);
signal v1: unsigned (31 downto 0):=x"00000000";
signal sum: unsigned (31 downto 0):=x"C6EF3720";
constant delta: unsigned (31 downto 0):=x"9e3779b9";
constant key: unsigned (127 downto 0):=x"ff0f745743fd99f775f8c48f2927c18c";
constant k0: unsigned (31 downto 0):=key(31 downto 0);
constant k1: unsigned (31 downto 0):=key(63 downto 32);
constant k2: unsigned (31 downto 0):=key(95 downto 64);
constant k3: unsigned (31 downto 0):=key(127 downto 96);
signal i: integer range -2 to 97:=-2;

begin

--process(clk )
--begin
--if(clk'event and clk='1')then
--	t1:=unsigned(ciphertext(31 downto 0));
--	t2:=unsigned(ciphertext(63 downto 32));
--end if;
--end process;


process(clk)
variable flag: std_logic := '0';

variable beg: std_logic := '0';
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
		plaintext<=x"00000000";
		beg :='0';
	else
		if (start='1') then
			flag:='1';
			beg :='1';
			if(i=-2) then 
				i<=-1;
	--			k0<=key(31 downto 0);
	--			k1<=key(63 downto 32);
	--			k2<=key(95 downto 64);
	--			k3<=key(127 downto 96);
				done <= '0';
				t1<=unsigned(ciphertext(31 downto 0));
				t2<=unsigned(ciphertext(63 downto 32));
			elsif(i=-1) then
				v0<=t1;
				v1<=t2;
				i<=0;
			elsif(i<96 and i>=0) then
				if((i mod 3)=0) then
					v1 <= v1 - ((shift_left(v0, 4) + k2) XOR (v0 + sum) XOR (shift_right(v0, 5) + k3));
				elsif((i mod 3)=1) then
					v0 <= v0 - ((shift_left(v1, 4) + k0) XOR (v1 + sum) XOR (shift_right(v1, 5) + k1));
				else
					sum <= sum - delta;
				end if;
				i<=i+1;
			else
				plaintext(31 downto 0)<=std_logic_vector(v1);
--				plaintext(63 downto 32)<=std_logic_vector(v1);
				done<='1';
				beg :='0';
			end if;
		elsif(flag='0' )then
			plaintext<=x"00000000";
		end if;
	end if;
end if;	
end process;
end Behavioral;