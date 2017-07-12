----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:21:22 03/15/2017 
-- Design Name: 
-- Module Name:    controller - Behavioral 
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

entity Controller_Top_Module is
	 generic (N : integer :=100);
    Port(clk : in  STD_LOGIC;
        reset : in  STD_LOGIC;
		  chanAddr_in  :in STD_LOGIC_VECTOR(6 downto 0);
		  h2fValid_in  :in STD_LOGIC;
		  h2fData_in   :in STD_LOGIC_VECTOR(7 downto 0);
        data_in_sliders : in  STD_LOGIC_VECTOR (7 downto 0);
        next_data_in_button : in  STD_LOGIC;
        start_button: in STD_LOGIC;
        done_button: in STD_LOGIC;
		  load_bank_id_button: in STD_LOGIC;
		  f2hData_out   :out STD_LOGIC_VECTOR(7 downto 0);
        data_out : out  STD_LOGIC_VECTOR (7 downto 0);
		  h2fReady_out : out std_logic;   -- channel logic can drive this low to say "I'm not ready for more data yet"
		  f2hValid_out : out std_logic);  -- channel logic can drive this low to say "I don't have data ready for you"
 
end Controller_Top_Module;

architecture Behavioral of Controller_Top_Module is
    component debouncer
        port(clk: in STD_LOGIC;
            button: in STD_LOGIC;
            button_deb: out STD_LOGIC);
    end component;

    component encrypter
        port(clk: in STD_LOGIC;
            reset : in  STD_LOGIC;
            plaintext: in STD_LOGIC_VECTOR (63 downto 0);
            start: in STD_LOGIC;
            ciphertext: out STD_LOGIC_VECTOR (63 downto 0);
            done: out STD_LOGIC);
    end component;

    component decrypter
        port(clk: in STD_LOGIC;
            reset : in  STD_LOGIC;
            ciphertext: in STD_LOGIC_VECTOR (63 downto 0);
            start: in STD_LOGIC;
            plaintext: out STD_LOGIC_VECTOR (31 downto 0);
            done: out STD_LOGIC);
    end component;

    component read_multiple_data_bytes
        port(
				clk : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            data_in : in  STD_LOGIC_VECTOR (7 downto 0);
            next_data : in  STD_LOGIC;
            data_read : out  STD_LOGIC_VECTOR (63 downto 0);
				bytes_read: out STD_LOGIC_VECTOR(3 downto 0):="0000");
    end component;

--
--    component display_leds
--        port(clk : in  STD_LOGIC;
--            reset : in  STD_LOGIC;
--            system_state : in  STD_LOGIC_VECTOR(3 downto 0);
--				bytes_read : in STD_LOGIC_VECTOR(3 downto 0);
--            data_out : out  STD_LOGIC_VECTOR (7 downto 0));
--    end component;


signal debounced_next_data_in_button: STD_LOGIC :='0';
signal debounced_start_button: STD_LOGIC:='0';
signal debounced_start_encrypt_button: STD_LOGIC:='0';
signal debounced_start_decrypt_button: STD_LOGIC:='0';
signal debounced_done_button: STD_LOGIC:='0'; 
signal debounced_load_bank_id_button: STD_LOGIC:='0';

 

signal multi_byte_data_read: STD_LOGIC_VECTOR (63 downto 0):=x"0000000000000000";
signal data_obtained_backend: STD_LOGIC_VECTOR (63 downto 0):=x"0000000000000000";
signal ciphertext_out: STD_LOGIC_VECTOR (63 downto 0) :=x"0000000000000000";
signal plaintext_out: STD_LOGIC_VECTOR (31 downto 0):=x"00000000";
signal data_to_be_displayed: STD_LOGIC_VECTOR (63 downto 0):=x"0000000000000000";

signal encryption_over: STD_LOGIC:='0';
signal decryption_over: STD_LOGIC:='0';
signal system_state: STD_LOGIC_VECTOR(3 downto 0);
signal debounced_reset: STD_LOGIC:='0';
signal chan_0: STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal chan_9: STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal n2000: unsigned(7 downto 0) := x"00" ;
signal n1000: unsigned(7 downto 0):=x"00" ;
signal n500: unsigned(7 downto 0):=x"00" ;
signal n100: unsigned(7 downto 0) := x"00" ;
signal plain:STD_LOGIC_VECTOR (31 downto 0):=x"00000000";

signal count : integer range 0 to 2*N:= 0; -- count for led
signal count_3 : integer range 0 to 3 := 0; -- count for insufficient funds in users account
signal count_6 : integer range 0 to 6 := 0; -- count for insufficient funds in atm account

signal count_5 : integer range 0 to 5 := 0; -- count for doing first five of dispensing cash.
signal count_2000 : integer range 0 to 255:= 0; -- count for how many 2000 notes are left to be dispensed.
signal count_1000 : integer range 0 to 255:= 0; -- count for how many 1000 notes are left to be dispensed.
signal count_500 : integer range 0 to 255:= 0; -- count for how many 500 notes are left to be dispensed.
signal count_100 : integer range 0 to 255:= 0; -- count for how many 100 notes are left to be dispensed.
signal check_dispensing_cash: STD_LOGIC:='0' ; -- to check whether the leds for dispensing cash have finished.
signal bytes_read : STD_LOGIC_VECTOR(3 downto 0):="0000"; -- count for led

signal counter: integer:=0; -- counter for 5*t for state change.

--signal address: integer range 0 to 7:=0; -- address for backend bits.
signal reset_for_other :STD_LOGIC := '0';
signal flag_decrypter:STD_LOGIC :='0';

signal bank_id: STD_LOGIC_VECTOR(4 downto 0):="00000";
signal number_notes:STD_LOGIC_VECTOR(2 downto 0):="000" ;
signal max_number_notes_2000:STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal max_number_notes_1000:STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal max_number_notes_500:STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal max_number_notes_100:STD_LOGIC_VECTOR(7 downto 0 ):= x"00";
signal counter_for_2000_loop:unsigned(7 downto 0 ):= x"00";
signal counter_for_1000_loop:unsigned(7 downto 0 ):= x"00";
signal counter_for_500_loop:unsigned(7 downto 0 ):= x"00";
signal counter_for_100_loop:unsigned(7 downto 0 ):= x"00";
signal copy_user_money_amount:unsigned (31 downto 0):=x"00000000";
signal copy_user_money_amount2:unsigned (31 downto 0):=x"00000000";

--------------------------for cache ----------------------------------------

type accountno1 is array (0 to 3) of std_logic_vector(15 downto 0);
type accountpin1 is array (0 to 3) of std_logic_vector(15 downto 0);
signal user_account_number: accountno1;
signal user_account_pin: accountpin1;
type money1 is array (0 to 3) of unsigned(31 downto 0);
signal user_account_money: money1;
type cache1 is array (0 to 3) of integer range 0 to 3;
signal user_account_cache: cache1;

signal stored_money_value:std_logic_vector(31 downto 0):=x"00000000";
--signal user_acc_num_from_backend:std_logic_vector(15 downto 0);
--signal user_acc_pin_from_backend:std_logic_vector(15 downto 0);
signal user_acc_money_from_backend:std_logic_vector(31 downto 0):=x"00000000";

signal counter_cache:integer range 0 to 7:=0;
signal checked_for_cache:STD_LOGIC :='0';
signal user_exists_in_cache:STD_LOGIC :='0';
signal temporary_cache_number:integer range 0 to 3:=0;

signal user_found_in_cache_for_backend:STD_LOGIC_VECTOR(7 downto 0) :=x"00";

begin

debouncer1: debouncer
              port map (clk => clk,
                        button => next_data_in_button,
                        button_deb => debounced_next_data_in_button);

debouncer2: debouncer
              port map (clk => clk,
                        button => done_button,
                        button_deb => debounced_done_button);

debouncer3: debouncer
              port map (clk => clk,
                        button => start_button,
                        button_deb => debounced_start_button);

debouncer4: debouncer
              port map (clk => clk,
                        button => reset,
                        button_deb => debounced_reset);
debouncer5: debouncer
              port map (clk => clk,
                        button => load_bank_id_button,
                        button_deb => debounced_load_bank_id_button);

data_inp: read_multiple_data_bytes
              port map (clk => clk,
                        reset => reset_for_other,
                        data_in => data_in_sliders,
                        next_data => debounced_next_data_in_button,
                        data_read => multi_byte_data_read,
								bytes_read=>bytes_read);
--display :display_leds
--					port map(clk =>clk,
--								reset =>reset,
--								system_state => system_state,
--								bytes_read =>bytes_read,
--								data_out => data_out);

encrypt: encrypter
              port map (clk => clk,
                        reset => reset_for_other,
                        plaintext => multi_byte_data_read,
                        start => debounced_start_encrypt_button,
                        ciphertext => ciphertext_out,
                        done => encryption_over);

decrypt: decrypter
              port map (clk => clk,                        
                        ciphertext => data_obtained_backend,
                        start => debounced_start_decrypt_button,
						reset => reset_for_other,
                        plaintext => plaintext_out,
                        done => decryption_over);

steer_enc_or_dec_output_to_display:
 process(clk)
 variable my_line : line;
 begin
 if(rising_edge(clk))then
	if(debounced_reset='1')then 
	n2000 <= x"00";
	n1000 <= x"00";
	n500 <= x"00";
	n100 <= x"00";	
	reset_for_other <= '1';
	system_state<="0000";  -- ready state
	counter<=0;
	chan_0<=x"00"; -- channel is not ready for listening
	debounced_start_encrypt_button<='0';
	counter_for_2000_loop<=x"00";
	counter_for_1000_loop<=x"00";
	counter_for_500_loop<=x"00";
	counter_for_100_loop<=x"00";
	copy_user_money_amount<=x"00000000";
	copy_user_money_amount2<=x"00000000";
	user_account_cache(0)<=0;
	user_account_cache(1)<=1;
	user_account_cache(2)<=2;
	user_account_cache(3)<=3;
	user_account_pin(0)<=x"eaf2";
	user_account_pin(1)<=x"eaf2";
	user_account_pin(2)<=x"eaf2";
	user_account_pin(3)<=x"eaf2";
	
	user_account_number(0)<=x"9e36";
	user_account_number(1)<=x"9e36";
	user_account_number(2)<=x"9e36";
	user_account_number(3)<=x"9e36";
--	f2hValid_out<='1';
--	h2fReady_out<='0';
	else
		counter<=counter+1;
		if(system_state="0000" AND debounced_load_bank_id_button = '1')then
			bank_id<=data_in_sliders(4 downto 0);
			system_state<="0001"; -- get user input state
			counter<=0;
			chan_0<=x"05";
			reset_for_other <= '0';
			user_account_cache(0)<=0;
			user_account_cache(1)<=1;
			user_account_cache(2)<=2;
			user_account_cache(3)<=3;
			
			user_account_pin(0)<=x"eaf2";
			user_account_pin(1)<=x"eaf2";
			user_account_pin(2)<=x"eaf2";
			user_account_pin(3)<=x"eaf2";
	
			user_account_number(0)<=x"9e36";
			user_account_number(1)<=x"9e36";
			user_account_number(2)<=x"9e36";
			user_account_number(3)<=x"9e36";
		
		elsif(system_state="0001" AND number_notes="100")then
			system_state<="0010";
			counter<=0;
			reset_for_other <= '0';
			chan_0<=x"00";
			
		elsif(system_state="0010" AND debounced_start_button = '1')then
	--	AND encryption_over='1') then
			system_state<="0011"; -- get user input state
			counter<=0;
			chan_0<=x"00";
			debounced_start_encrypt_button<='0';
			reset_for_other <= '0';
--			f2hValid_out<='1';
--			h2fReady_out<='0';
		elsif(system_state="0011" AND bytes_read="1000" )then
			system_state<="0100";		-- Communicating with the board.
			debounced_start_encrypt_button<='1';
			counter<=0;
			copy_user_money_amount<=x"00000000";
			copy_user_money_amount2<=x"00000000";
--			f2hValid_out<='0';
--			h2fReady_out<='1';
		
		elsif(system_state="0100" AND encryption_over='1')then
			copy_user_money_amount(31 downto 24)<=unsigned(multi_byte_data_read(39 downto 32));
			copy_user_money_amount(23 downto 16)<=unsigned(multi_byte_data_read(47 downto 40));
			copy_user_money_amount(15 downto 8)<=unsigned(multi_byte_data_read(55 downto 48));
			copy_user_money_amount(7 downto 0)<=unsigned(multi_byte_data_read(63 downto 56));

			copy_user_money_amount2(31 downto 24)<=unsigned(multi_byte_data_read(39 downto 32));
			copy_user_money_amount2(23 downto 16)<=unsigned(multi_byte_data_read(47 downto 40));
			copy_user_money_amount2(15 downto 8)<=unsigned(multi_byte_data_read(55 downto 48));
			copy_user_money_amount2(7 downto 0)<=unsigned(multi_byte_data_read(63 downto 56));

			system_state<="0101";
			counter_cache<=0;
			user_found_in_cache_for_backend<=x"00";
			stored_money_value<=x"00000000";
			checked_for_cache<='0';
			counter_for_2000_loop<=x"00";
			counter_for_1000_loop<=x"00";
			counter_for_500_loop<=x"00";
			counter_for_100_loop<=x"00";
			user_exists_in_cache<='0';
----------------------------------------------------------------------------------------------
		elsif(system_state="0101" and checked_for_cache='0' and counter_cache<4)then
			if(user_account_number(counter_cache)=multi_byte_data_read(15 downto 0) and user_account_pin(counter_cache)=multi_byte_data_read(31 downto 16))then
				stored_money_value<=std_logic_vector(user_account_money(counter_cache));
				user_found_in_cache_for_backend<=x"01";
			end if;
			if(counter_cache=3)then
				checked_for_cache<='1';
				counter_cache<=0;
			else
				counter_cache<=counter_cache+1;
			end if;
----------------------------------------------------------------------------------------------
		elsif(system_state="0101" and checked_for_cache='1')then
			if(copy_user_money_amount>=2000 and counter_for_2000_loop<n2000 and counter_for_2000_loop<unsigned(max_number_notes_2000))then
				copy_user_money_amount<=copy_user_money_amount-2000;
				counter_for_2000_loop<=counter_for_2000_loop+1;

			elsif(copy_user_money_amount>=1000 and counter_for_1000_loop<n1000 and counter_for_1000_loop<unsigned(max_number_notes_1000))then
				copy_user_money_amount<=copy_user_money_amount-1000;
				counter_for_1000_loop<=counter_for_1000_loop+1;

			elsif(copy_user_money_amount>=500 and counter_for_500_loop<n500 and counter_for_500_loop<unsigned(max_number_notes_500))then
				copy_user_money_amount<=copy_user_money_amount-500;
				counter_for_500_loop<=counter_for_500_loop+1;

			elsif(copy_user_money_amount>=100 and counter_for_100_loop<n100 and counter_for_100_loop<unsigned(max_number_notes_100))then
				copy_user_money_amount<=copy_user_money_amount-100;
				counter_for_100_loop<=counter_for_100_loop+1;
			elsif(copy_user_money_amount=0)then
				checked_for_cache<='0';
				chan_0<=x"01";
--				multi_byte_data_read(39 downto 32)<=STD_LOGIC_VECTOR(counter_for_2000_loop);
--				multi_byte_data_read(47 downto 40)<=STD_LOGIC_VECTOR(counter_for_1000_loop);
--				multi_byte_data_read(55 downto 48)<=STD_LOGIC_VECTOR(counter_for_500_loop);
--				multi_byte_data_read(63 downto 56)<=STD_LOGIC_VECTOR(counter_for_100_loop);
				system_state<="0110";
				counter_cache<=0;
			else
				checked_for_cache<='0';
				chan_0<=x"02";
				system_state<="0110";
				counter<=0;
				counter_cache<=0;
			end if;

				
		--elsif(system_state="0100" AND encryption_over='1')then
		
		--	if(n2000<unsigned(multi_byte_data_read(39 downto 32)))then
		--		chan_0<=x"02";	-- not sufficient balance in atm
		--	elsif(n1000<unsigned(multi_byte_data_read(47 downto 40)))then
		--		chan_0<=x"02";	-- not sufficient balance in atm
		--	elsif(n500<unsigned(multi_byte_data_read(55 downto 48)))then
		--		chan_0<=x"02";	-- not sufficient balance in atm
		--	elsif(n100<unsigned(multi_byte_data_read(63 downto 56)))then
		--		chan_0<=x"02";	-- not sufficient balance in atm	
		--	else
		--		chan_0<=x"01";	-- c will start listening
		--	end if;
		--	system_state<="0101";	-- c se interacction over
		--	counter<=0;
		elsif(system_state="0110" and checked_for_cache='0' and counter_cache<4 and counter<100*N)then
			if(decryption_over='1' and flag_decrypter='1')then
				counter<=0;
--				chan_0<=x"03";
				if(chan_9="00000001" or chan_9="00000010")then
					if(user_account_number(counter_cache)=multi_byte_data_read(15 downto 0) and user_account_pin(counter_cache)=multi_byte_data_read(31 downto 16))then
						temporary_cache_number<=user_account_cache(counter_cache);
						user_exists_in_cache<='1'; ---------initialize-------
					end if;
					counter_cache<=counter_cache+1;
				else 
					checked_for_cache<='1';
					
				end if;
			end if;
		
		elsif(system_state="0110" and checked_for_cache='0' and counter<100*N and counter_cache<8 and user_exists_in_cache='1')then

			if(user_account_cache(counter_cache-4)=temporary_cache_number)then
				user_account_cache(counter_cache-4)<=3;
				user_account_money(counter_cache-4)<=unsigned(user_acc_money_from_backend);
					------------------not enough money in the users account--------

			elsif(user_account_cache(counter_cache-4)>temporary_cache_number)then
				user_account_cache(counter_cache-4)<=user_account_cache(counter_cache-4)-1;
			end if;

			if(counter_cache=7)then
				checked_for_cache<='1';
				user_exists_in_cache<='0';
				temporary_cache_number<=0;
				counter_cache<=0;
			else
				counter_cache<=counter_cache+1;
			end if;


		elsif(system_state="0110" and checked_for_cache='0' and counter<100*N and counter_cache<8 and user_exists_in_cache='0')then

			if(user_account_cache(counter_cache-4)=0)then
				user_account_number(counter_cache-4)<=multi_byte_data_read(15 downto 0);
				user_account_pin(counter_cache-4)<=multi_byte_data_read(31 downto 16);
				user_account_money(counter_cache-4)<=unsigned(user_acc_money_from_backend);
				user_account_cache(counter_cache-4)<=3;
			else
					------------all others cache num should decrease by 1--------
				user_account_cache(counter_cache-4)<=user_account_cache(counter_cache-4)-1;
			end if;

			if(counter_cache=7)then
				checked_for_cache<='1';
				user_exists_in_cache<='0';
				temporary_cache_number<=0;
				counter_cache<=0;
			else
				counter_cache<=counter_cache+1;
			end if;


		elsif(system_state="0110" and counter<100*N and checked_for_cache='1')then
--			if(decryption_over='1' and flag_decrypter='1' and chan_0=x"02")then  -- for the case in which atm does not have enough cash
--				system_state<="1000";
			user_exists_in_cache<='0';
			if(chan_9="00000001" and decryption_over='1' and flag_decrypter='1')then
				if(chan_0=x"02")then
					system_state<="1100";
				else
					system_state<="0111";
				end if;
				counter<=0;
				chan_0<=x"03";
			elsif(chan_9="00000010" and decryption_over='1' and flag_decrypter='1')then
				system_state<="1000";
				counter<=0;
				chan_0<=x"03";
			elsif(chan_9="00000011" and decryption_over='1' and flag_decrypter='1')then
				if(plaintext_out=x"00000000")then
					counter_for_2000_loop<=unsigned(plaintext_out(7 downto 0));
				end if;
				system_state<="1001";
				counter<=0;
				chan_0<=x"03";
			elsif(chan_9="00000100" and decryption_over='1' and flag_decrypter='1')then
				system_state<="1010";
				counter<=0;
				chan_0<=x"03";
				
			counter<=counter+1;

			end if;
-------------------------------------------------------------------------------------------------------------
		elsif(system_state="0110" and counter>=100*N and counter_cache<4)then -- when it has timed out...
			if(user_account_number(counter_cache)=multi_byte_data_read(15 downto 0) and user_account_pin(counter_cache)=multi_byte_data_read(31 downto 16))then
				temporary_cache_number<=user_account_cache(counter_cache);
				user_exists_in_cache<='1'; ---------initialize-------
			end if;
			counter_cache<=counter_cache+1;

		elsif(system_state="0110" and counter>=100*N and counter_cache<8 and user_exists_in_cache='1')then -- when it has timed out...
			
			if(user_account_cache(counter_cache-4)=temporary_cache_number)then
				user_account_cache(counter_cache-4)<=3;
				if(user_account_money(counter_cache-4)<copy_user_money_amount2)then
					------------------not enough money in the users account--------
					counter_cache<=0;
					system_state<="1000"; 
					counter<=0;
				else
					---------enough money---------
					if(chan_0=x"02")then
						system_state<="1100";
					else
					-------atm also has money so dispensing---
						system_state<="0111";
						user_account_money(counter_cache-4)<=user_account_money(counter_cache-4)-copy_user_money_amount2;
					end if;
					counter<=0;
					counter_cache<=0;
				end if;

			elsif(user_account_cache(counter_cache-4)>temporary_cache_number)then
				user_account_cache(counter_cache-4)<=user_account_cache(counter_cache-4)-1;
			end if;

			counter_cache<=counter_cache+1;

		elsif(system_state="0110" and counter>=100*N and counter_cache<8 and user_exists_in_cache='0')then
			--------------------user not validated------------as not in cache----------

			counter<=0;
			counter_cache<=0;
			system_state<="1010";


----------------------------------------------------------------------------------------------
		elsif(system_state="0111" and counter >5*N and check_dispensing_cash='1')then -- user validated and sufficient fund
			plain<=plaintext_out;
			if(plain=x"00000000")then
				write(my_line, string'("Hello World2"));   -- formatting
				writeline(output, my_line);               -- write to "output"	
			else
				write(my_line, string'("Hello World1"));   -- formatting
				writeline(output, my_line);               -- write to "output"	
			end if;
--			n2000<=n2000 - unsigned(multi_byte_data_read(39 downto 32));
--			n1000<=n1000- unsigned(multi_byte_data_read(47 downto 40));
--			n500<=n500 - unsigned(multi_byte_data_read(55 downto 48));
--			n100<=n100 - unsigned(multi_byte_data_read(63 downto 56));
			n2000<=n2000 - counter_for_2000_loop;
			n1000<=n1000 - counter_for_1000_loop;
			n500<=n500 - counter_for_500_loop;
			n100<=n100 - counter_for_100_loop;
			
			counter<=0;
			counter_cache<=0;
			system_state<="1011";
			
		elsif(system_state="1000" and counter=8*N)then  -- user validated but not sufficient fund
		
			counter<=0;
			counter_cache<=0;
			system_state<="1011";
			
		elsif(system_state="1001" and counter =11*N)then -- admin user validated
			n2000<=unsigned(multi_byte_data_read(39 downto 32));
			n1000<=unsigned(multi_byte_data_read(47 downto 40));
			n500<=unsigned(multi_byte_data_read(55 downto 48));
			n100<=unsigned(multi_byte_data_read(63 downto 56));
			
			counter<=0;
			counter_cache<=0;
			system_state<="1011";
			
		elsif(system_state="1010")then  -- user pin does not match
			
			counter<=0;
			counter_cache<=0;
			system_state<="1011";
			
		elsif(system_state="1011" and debounced_done_button ='1')then
			counter<=0;
			counter_cache<=0;
			system_state<="0010";
			reset_for_other <= '1';
			chan_0<=x"00";
			
		elsif(system_state="1100" and counter=14*N)then
			counter<=0;
			system_state<="1011";
			
		end if;
	end if;
end if;
 end process;
 
 process(clk) 
 begin
	if(rising_edge(clk))then
		if(debounced_reset='1')then 
		debounced_start_decrypt_button<='0';
		f2hValid_out<='1';
		h2fReady_out<='1';
		flag_decrypter<='0';
		number_notes<="000";
		else
			if(system_state="0010")then
				debounced_start_decrypt_button<='0';
				f2hValid_out<='1';
				h2fReady_out<='1';
				flag_decrypter<='0';
			elsif(system_state="0111" or system_state="1000" or system_state="1001" or system_state="1010" or system_state="1100")then
				flag_decrypter<='0';
			end if;
			if(chanAddr_in ="0000000")then
				f2hData_out<=chan_0;
--				elsif(encryption_over='0')then
--					f2hValid_out<='0';
--					h2fReady_out<='0';

--	-------------CHANGED FOR PROJECT --------------------------------------
			elsif(system_state="0001" and chan_0=x"05" and h2fValid_in = '1')then
				if(chanAddr_in="0000001" and number_notes="000")then
					max_number_notes_2000<=h2fData_in;
					number_notes<="001";
				elsif(chanAddr_in="0000010" and number_notes="001")then
					max_number_notes_1000<=h2fData_in;
					number_notes<="010";
				elsif(chanAddr_in="0000011" and number_notes="010")then
					max_number_notes_500<=h2fData_in;
					number_notes<="011";
				elsif(chanAddr_in="0000100" and number_notes="011")then
					max_number_notes_100<=h2fData_in;
					number_notes<="100";
				end if;
				
				else
--					h2fReady_out<='0';
					if(chanAddr_in ="0000001")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(7 downto 0);
					elsif(chanAddr_in ="0000010")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(15 downto 8);
					elsif(chanAddr_in ="0000011")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(23 downto 16);
					elsif(chanAddr_in ="0000100")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(31 downto 24);
					elsif(chanAddr_in ="0000101")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(39 downto 32);
					elsif(chanAddr_in ="0000110")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(47 downto 40);		
					elsif(chanAddr_in ="0000111")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(55 downto 48);
					elsif(chanAddr_in ="0001000")then
--						f2hValid_out<='1';
						f2hData_out<=ciphertext_out(63 downto 56);

---------------	------------------------------------------------------changed for cache-------------------------
					elsif(h2fValid_in = '0' and chanAddr_in="0001001")then -- channel 9
						f2hData_out<=user_found_in_cache_for_backend;
					elsif(h2fValid_in = '0' and chanAddr_in="0001010")then -- channel 10
						f2hData_out<=stored_money_value(31 downto 24);
					elsif(h2fValid_in = '0' and chanAddr_in="0001011")then
						f2hData_out<=stored_money_value(23 downto 16);
					elsif(h2fValid_in = '0' and chanAddr_in="0001100")then
						f2hData_out<=stored_money_value(15 downto 8);
					elsif(h2fValid_in = '0' and chanAddr_in="0001101")then -- channel 13
						f2hData_out<=stored_money_value(7 downto 0);
	------------------------------------------------------changed for cache-------------------------
					--elsif(h2fValid_in = '0' and chanAddr_in="0001101")then
					--	f2hData_out<=stored_money_value(63 downto 56);
					--elsif(h2fValid_in = '0' and chanAddr_in="0001110")then
					--	f2hData_out<=stored_money_value(63 downto 56);
					--elsif(h2fValid_in = '0' and chanAddr_in="0001111")then
					--	f2hData_out<=stored_money_value(63 downto 56);
					--elsif(h2fValid_in = '0' and chanAddr_in="0010000")then
					--	f2hData_out<=stored_money_value(63 downto 56);

					elsif(h2fValid_in = '1')then
--						h2fReady_out<='1';
				--		arr(to_integer(unsigned(chanAddr_in)))<=h2fData_in;
						if(chanAddr_in="0001001")then
							chan_9<=h2fData_in;

			------------------------------------------------------changed for cache-------------------------
--						elsif(chanAddr_in="0001010")then -- channel 10
--							user_acc_money_from_backend(7 downto 0)<=h2fData_in;
--						elsif(chanAddr_in="0001011")then -- channel 11
--							user_acc_money_from_backend(15 downto 8)<=h2fData_in;
--						elsif(chanAddr_in="0001100")then -- channel 12
--							user_acc_money_from_backend(23 downto 16)<=h2fData_in;
--						elsif(chanAddr_in="0001101")then -- channel 13
--							user_acc_money_from_backend(31 downto 24)<=h2fData_in;


						elsif(unsigned(chanAddr_in)<"0010010")then
--							address<=to_integer(unsigned(chanAddr_in))-10;
							data_obtained_backend(((to_integer(unsigned(chanAddr_in))-10)*8+7) downto (to_integer(unsigned(chanAddr_in))-10)*8)<=h2fData_in;
							if((chan_9=x"03" or chan_9=x"04") and chanAddr_in="0010001")then
								debounced_start_decrypt_button<='1';
								flag_decrypter<='1';
							end if;
							
						elsif(chanAddr_in="0010010")then -- channel 18
							user_acc_money_from_backend(31 downto 24)<=h2fData_in;
						elsif(chanAddr_in="0010011")then -- channel 19
							user_acc_money_from_backend(23 downto 16)<=h2fData_in;
						elsif(chanAddr_in="0010100")then -- channel 20
							user_acc_money_from_backend(15 downto 8)<=h2fData_in;
						elsif(chanAddr_in="0010101")then -- channel 21
							user_acc_money_from_backend(7 downto 0)<=h2fData_in;
							debounced_start_decrypt_button<='1';
							flag_decrypter<='1';
							
				------------------------------------------------------changed for cache-------------------------				
						end if;			
--					else
--						h2fReady_out<='0';
--						f2hValid_out<='0';
					end if;
				end if;
			end if;
	end if;
	
	
 end process;
 
 
 process(clk)
 variable blink: std_logic := '0';
-- variable state_is_occuring_first_time: std_logic := '0';
 begin
 	if(rising_edge(clk))then
		if(reset = '1')then
			data_out <= "00000000";
			blink := '0';
			count <= 0;
			count_3<=0;
			count_6<=0;
			count_5<=0;
			count_2000<=0;
			count_1000<=0;
			count_500<=0;
			count_100<=0;
			check_dispensing_cash<='0';
--			N <= 100; 
		else
			if(system_state="0010")then	 ------------base case
				count_3<=0;
				count_6<=0;
				count_5<=0;
				count_2000<=0;
				count_1000<=0;
				count_500<=0;
				count_100<=0;
				check_dispensing_cash<='0';
				data_out(7 downto 0)<=x"00";
			elsif(system_state = "0011")then   ------------------ one by one blink to display output of bits entered so far
				if(blink = '0' and count < N)then
					data_out(0) <= '0';
					data_out(3 downto 1) <= bytes_read(2 downto 0);
					data_out(7 downto 4) <="0000";
					count <= count + 1;
					blink := '0';
				elsif(blink = '0' and count = N)then
					data_out(0) <= '0';
					data_out(3 downto 1) <= bytes_read(2 downto 0);
					data_out(7 downto 4) <="0000";
					blink := '1';
					count<= 0;
				elsif(blink = '1' and count < N)then
					data_out(0) <= '1';
					data_out(3 downto 1) <= bytes_read(2 downto 0);
					data_out(7 downto 4) <="0000";
					blink := '1';
					count<= count + 1;
				elsif(blink = '1' and count = N)then
					data_out(0) <= '1';
					data_out(3 downto 1) <= bytes_read(2 downto 0);
					data_out(7 downto 4) <="0000";
					blink := '0';
					count<= 0;	
				end if;
				
				
			elsif(system_state = "0100" or system_state = "0101" or system_state = "0110")then 
				-- BLINK THE first two leds
				
				if(blink = '0' and count < N)then
					data_out(0) <= '0';
					data_out(1)<='0';
					data_out(7 downto 2) <="000000";
					count <= count + 1;
					blink := '0';
				elsif(blink = '0' and count = N)then
					data_out(0) <= '0';
					data_out(1)<='0';
					data_out(7 downto 2) <="000000";
					blink := '1';
					count<= 0;
				elsif(blink = '1' and count < N)then
					data_out(0) <= '1';
					data_out(1)<='1';
					data_out(7 downto 2) <="000000";
					blink := '1';
					count<= count + 1;
				elsif(blink = '1' and count = N)then
					data_out(0) <= '1';
					data_out(1)<='1';
					data_out(7 downto 2) <="000000";
					blink := '0';
					count<= 0;	
				end if;
			
			elsif(system_state="1100" and count_6 <6)then 
			-- not sufficient funds in the atm module.
				if(blink = '0' and count < N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="0000";
					count <= count + 1;
					blink := '0';
				elsif(blink = '0' and count = N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="0000";
					blink := '1';
					count<= 0;
				elsif(blink = '1' and count < N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="1111";
					blink := '1';
					count<= count + 1;
				elsif(blink = '1' and count = N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="1111";
					blink := '0';
					count<= 0;
					count_6<=count_6+1;					
				end if;
				
			elsif(system_state = "0111")then
				-- dispensing cash 
				if(count_5<5)then
					if(blink = '0' and count < N)then
						data_out(3 downto 0)<="0000";
						data_out(7 downto 4) <="0000";
						count <= count + 1;
						blink := '0';
					elsif(blink = '0' and count = N)then
						data_out(3 downto 0)<="0000";
						data_out(7 downto 4) <="0000";
						blink := '1';
						count<= 0;
					elsif(blink = '1' and count < N)then
						data_out(3 downto 0)<="1111";
						data_out(7 downto 4) <="0000";
						blink := '1';
						count<= count + 1;
					elsif(blink = '1' and count = N)then
						data_out(3 downto 0)<="1111";
						data_out(7 downto 4) <="0000";
						blink := '0';
						count<= 0;	
						count_5<=count_5+1;
					end if;
				else
					if(count_2000<to_integer(counter_for_2000_loop))then
						if(blink = '0' and count < 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(4)<='0';
							data_out(7 downto 5) <="000";
							count <= count + 1;
							blink := '0';
						elsif(blink = '0' and count = 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(4)<='0';
							data_out(7 downto 5) <="000";
							blink := '1';
							count<= 0;
						elsif(blink = '1' and count < N)then
							data_out(3 downto 0)<="1111";
							data_out(4)<='1';
							data_out(7 downto 5) <="000";
							blink := '1';
							count<= count + 1;
						elsif(blink = '1' and count = N)then
							data_out(3 downto 0)<="1111";
							data_out(4)<='1';
							data_out(7 downto 5) <="000";
							blink := '0';
							count<= 0;	
							count_2000<=count_2000+1;
						end if;
					elsif(count_1000<to_integer(counter_for_1000_loop))then
						if(blink = '0' and count < 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(5)<='0';
							data_out(4)<='0';
							data_out(7 downto 6) <="00";
							count <= count + 1;
							blink := '0';
						elsif(blink = '0' and count = 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(5)<='0';
							data_out(4)<='0';
							data_out(7 downto 6) <="00";
							blink := '1';
							count<= 0;
						elsif(blink = '1' and count < N)then
							data_out(3 downto 0)<="1111";
							data_out(5)<='1';
							data_out(4)<='0';
							data_out(7 downto 6) <="00";
							blink := '1';
							count<= count + 1;
						elsif(blink = '1' and count = N)then
							data_out(3 downto 0)<="1111";
							data_out(5)<='1';
							data_out(4)<='0';
							data_out(7 downto 6) <="00";
							blink := '0';
							count<= 0;	
							count_1000<=count_1000+1;
						end if;
					elsif(count_500<to_integer(counter_for_500_loop))then
						if(blink = '0' and count < 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(5 downto 4)<="00";
							data_out(6)<='0';
							data_out(7) <='0';
							count <= count + 1;
							blink := '0';
						elsif(blink = '0' and count = 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(5 downto 4)<="00";
							data_out(6)<='0';
							data_out(7) <='0';
							blink := '1';
							count<= 0;
						elsif(blink = '1' and count < N)then
							data_out(3 downto 0)<="1111";
							data_out(5 downto 4)<="00";
							data_out(6)<='1';
							data_out(7) <='0';
							blink := '1';
							count<= count + 1;
						elsif(blink = '1' and count = N)then
							data_out(3 downto 0)<="1111";
							data_out(5 downto 4)<="00";
							data_out(6)<='1';
							data_out(7) <='0';
							blink := '0';
							count<= 0;	
							count_500<=count_500+1;
						end if;
						
					elsif(count_100<to_integer(counter_for_100_loop))then
						if(blink = '0' and count < 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(6 downto 4)<="000";
							data_out(7) <='0';
							count <= count + 1;
							blink := '0';
						elsif(blink = '0' and count = 2*N)then
							data_out(3 downto 0)<="0000";
							data_out(6 downto 4)<="000";
							data_out(7) <='0';
							blink := '1';
							count<= 0;
						elsif(blink = '1' and count < N)then
							data_out(3 downto 0)<="1111";
							data_out(6 downto 4)<="000";
							data_out(7) <='1';
							blink := '1';
							count<= count + 1;
						elsif(blink = '1' and count = N)then
							data_out(3 downto 0)<="1111";
							data_out(6 downto 4)<="000";
							data_out(7) <='1';
							blink := '0';
							count<= 0;	
							count_100<=count_100+1;
						end if;
					else
						check_dispensing_cash<='1'; -- dispensing done
					end if;
					
				end if;
				
				
				
			elsif(system_state = "1000" and count_3<3)then
				-- not sufficient funds in users account
				
				if(blink = '0' and count < N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="0000";
					count <= count + 1;
					blink := '0';
				elsif(blink = '0' and count = N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="0000";
					blink := '1';
					count<= 0;
				elsif(blink = '1' and count < N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="1111";
					blink := '1';
					count<= count + 1;
				elsif(blink = '1' and count = N)then
					data_out(3 downto 0)<="0000";
					data_out(7 downto 4) <="1111";
					blink := '0';
					count<= 0;	
					count_3<=count_3+1;
				end if;
				
			elsif(system_state = "1001")then 
				-- loading cash 
				if(blink = '0' and count < N)then
					data_out(2 downto 0)<="000";
					data_out(7 downto 3) <="00000";
					count <= count + 1;
					blink := '0';
				elsif(blink = '0' and count = N)then
					data_out(2 downto 0)<="000";
					data_out(7 downto 3) <="00000";
					blink := '1';
					count<= 0;
				elsif(blink = '1' and count < N)then
					data_out(2 downto 0)<="111";
					data_out(7 downto 3) <="00000";
					blink := '1';
					count<= count + 1;
				elsif(blink = '1' and count = N)then
					data_out(2 downto 0)<="111";
					data_out(7 downto 3) <="00000";
					blink := '0';
					count<= 0;	
				end if;
				
			elsif(system_state = "1010")then
				-- user not validated
				
			end if;
		end if;
	end if;
 
 end process;
 
 
 
 
 
--
-- data_to_be_displayed <= ciphertext_out when (system_state = '0') else
--                         plaintext_out;
-- done <= encryption_over AND decryption_over;
-- 
end Behavioral;
