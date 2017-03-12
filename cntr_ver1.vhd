library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity cntr_ver1 is
	port (
		rst_i: in std_logic; -- reset
		time_base_clk_i: in std_logic; -- time base
		x_clk_i: in std_logic; -- clock to be counted
		ctrl_clk_i: in std_logic; -- clock for FSM
		-- signals for HDSP-210X, -211X oder -250X
		disp_a_o: out std_logic_vector(4 downto 0); -- address bits
		disp_d_o: out std_logic_vector(7 downto 0); -- data bus
		disp_nrst_o: out std_logic; -- reset
		disp_nwr_o: out std_logic; -- "write"
		disp_nce_o: out std_logic -- "chip enable"
	);
end entity cntr_ver1;

architecture arch_cntr_ver1 of cntr_ver1 is

	type digit_type is array(0 to 7) of std_logic_vector(3 downto 0);
	signal digit: digit_type;

	signal count: std_logic;
	signal old_count: std_logic;

	signal digit_cntr: std_logic_vector(2 downto 0);
	--signal state_cntr: std_logic_vector(digit_cntr'length downto 0);

	type states is (
		reset_state,
		wait_state,
		addr_setup_state,
		chip_enable_state,
		write_state,
		chip_disable_state
	);

	signal state, next_state: states;

begin

	count <= rst_i or time_base_clk_i;

	-- Count unknown clock
	count_x_clk_i: process(count, x_clk_i, old_count, digit)
	begin
		if (count = '1') then
			old_count <= '0';
		elsif (x_clk_i = '1' and x_clk_i'event) then
			old_count <= '1';
			if (old_count = '0') then
				digit(0) <= "0001";
				for k in 1 to digit'length-1 loop
					digit(k) <= (others => '0');
				end loop;
			else
				for k in digit'range loop
					if (digit(k)(3) and digit(k)(0)) = '1' then
						digit(k) <= (others => '0');
					else
						digit(k) <= digit(k) + 1;
						exit;
					end if;
				end loop;
			end if;
		end if;
	end process count_x_clk_i;

	-- FSM: Input logic of the state machine
	input_ctrl: process(state)
	begin
		next_state <= reset_state; -- "default"-state
		case state is
			when reset_state =>
				next_state <= wait_state;
			when wait_state =>
				next_state <= addr_setup_state;
			when addr_setup_state =>
				next_state <= chip_enable_state;
			when chip_enable_state =>
				next_state <= write_state;
			when write_state =>
				next_state <= chip_disable_state;
			when chip_disable_state =>
				next_state <= wait_state;
			when others => null;
		end case;
	end process input_ctrl;

	-- FSM: State register
	state_ctrl: process(rst_i, ctrl_clk_i, next_state, digit_cntr)
	begin
		if (rst_i = '1') then
			digit_cntr <= (others => '0');
			state <= reset_state;
		elsif (ctrl_clk_i = '1' and ctrl_clk_i'event) then
			state <= next_state;
			if (state = chip_disable_state) then
				digit_cntr <= digit_cntr + 1;
			end if;
		end if;
	end process state_ctrl;

	-- FSM: Output logic of the state machine
	output_ctrl: process(state, digit_cntr, digit)
	begin
		disp_nrst_o <= '1';
		disp_nce_o <= '1';
		disp_nwr_o <= '1';
		disp_a_o(4 downto 3) <= "11";
		disp_a_o(digit_cntr'range) <= not digit_cntr; -- "000" left most, "111" right most
		disp_d_o(7 downto 4) <= "0011";
		disp_d_o(digit(0)'range) <= digit(conv_integer(digit_cntr));
		case state is
			when reset_state =>
				disp_nrst_o <= '0';
			when chip_enable_state =>
				disp_nce_o <= '0';
				disp_nwr_o <= '1';
			when write_state =>
				disp_nce_o <= '0';
				disp_nwr_o <= '0';
			when others => null;
		end case;
	end process output_ctrl;

end architecture arch_cntr_ver1;
