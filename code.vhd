library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
port (
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_start : in std_logic;
    i_data : in std_logic_vector(7 downto 0);
    o_address : out std_logic_vector(15 downto 0);
    o_done : out std_logic;
    o_en : out std_logic;
    o_we : out std_logic;
    o_data : out std_logic_vector (7 downto 0)
);
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type S is(
    START,
    READ_START,
    WAIT_R_START_1,
    WAIT_R_START_2,
    W1,
    W2,
    PK,
    WORD_CONSTRUCTION,
    W3,
    WRITE_WORD,
    WRITE_WORD_2,
    WAIT_W_WORD,
    DONE
    );

signal cur_bit: unsigned(3 downto 0) := (others => '0');
signal out_counter : unsigned(3 downto 0) := (others => '0');
signal written_first_half : std_logic := '0';
signal num_words: unsigned(7 downto 0) := (others => '0'); 
signal w_add, r_add : std_logic_vector(15 downto 0) := (others => '0');
signal word_out : std_logic_vector(15 downto 0) := (others => '0');
signal word_in : std_logic_vector(7 downto 0) := (others => '0');
signal cur_word : std_logic_vector(7 downto 0) := (others => '0');
signal uk, uk1, uk2 : std_logic := '0';
signal pk1, pk2 : std_logic := '0';
signal ff_en : std_logic := '0';
signal ff_rst : std_logic := '0';
signal got_n_words, got_input_buffer: BOOLEAN := false;
signal cur_state : S := START;

component ffd is
     port(  clk, en, rst : in std_logic;
            in1 : in std_logic;
            out1 : out std_logic
     );
end component;
    
    begin

    D1: ffd
        port map(i_clk, ff_en, ff_rst, uk, uk1);
    D2: ffd
        port map(i_clk, ff_en, ff_rst, uk1, uk2);
 
process(i_clk)
 begin
    if rising_edge(i_clk) then
         o_done <= '0';
         o_en <= '0';
         o_we <= '0';
         o_address <= (others => '0');
         o_data <= (others => '0');
         if i_rst = '1' then
             cur_state <= START;
         end if;
        case cur_state is
           when START =>
               got_n_words <= false;
               got_input_buffer <= false;
               cur_word <= "00000001";
               written_first_half <= '0';
               w_add <= "0000001111101000";
               r_add <= (others => '0');
               word_out <= (others => '0');                                   
               if i_start = '1' then
                   cur_state <= READ_START;
                   ff_en <= '1';
                   ff_rst <= '1';
                   uk <= '0';
               else
                   cur_state <= START;
                   o_done <= '0';
               end if;
           when READ_START =>
               cur_bit <= (others => '0');
               ff_rst <= '0';
               ff_en <= '0';
               o_en <= '1';
               o_we <= '0';
               IF(NOT got_n_words) THEN
                  o_address<= "0000000000000000";
               ELSIF(NOT got_input_buffer) THEN 
                  o_address <= "0000000000000000" + cur_word;
               END IF;
               cur_state <= WAIT_R_START_1;
           when WAIT_R_START_1 =>
               IF (got_input_buffer AND got_n_words) THEN             
                  cur_state <= PK;
               ELSE
                  ff_en <= '0';
                  cur_state <= WAIT_R_START_2;
               END IF;
           when WAIT_R_START_2 =>
               IF (NOT got_n_words) THEN
                  num_words <= unsigned(i_data) after 3 ns;
                  got_n_words <= true;
                  cur_state <= W1;
               ELSE               
                  word_in <= i_data after 3 ns;
                  cur_word <= cur_word +1;
                  got_input_buffer <= true;
                  cur_state <= W2;
               END IF;
           when W1 =>
               if unsigned(num_words) = 0 then
                  o_done <= '1';
                  cur_state <= DONE;
               else
                  cur_state <= READ_START after 3 ns;
               end if;
           when W2 => 
               cur_state <= PK after 3 ns; 
           when PK =>
               pk1 <= std_logic((word_in(to_integer(7 - cur_bit)) XOR uk2));
               pk2 <= std_logic((word_in(to_integer(7 - cur_bit)) XOR uk2 XOR uk1));
               cur_state <= WORD_CONSTRUCTION;
           when WORD_CONSTRUCTION =>
               o_en <= '0';
               ff_en <= '1';                         
               uk <= word_in(to_integer(7 - cur_bit));
               word_out (to_integer(15 - out_counter )) <= pk1;
               word_out (to_integer(15 - out_counter -1)) <= pk2;
               out_counter <= out_counter +2;
               cur_bit <= cur_bit +1;                           
               if out_counter = 14 then
                  out_counter <= (others => '0');
                  cur_state <= WRITE_WORD;
                  ff_en <= '0';                 
               else
                  cur_state <= W3;
                  ff_en <= '1';
               end if;
           when W3 =>
               ff_en <= '0';
               cur_state <= PK;                                 
           when WRITE_WORD =>
               ff_en <= '0';
               o_en <= '1';
               o_we <= '1';
               o_address <= w_add;
               o_data <= word_out(15 downto 8);
               w_add <= w_add + 1;
               cur_state <= WRITE_WORD_2;
           when WRITE_WORD_2=>
               ff_en <= '0';
               o_en <= '1';
               o_we <= '1';
               o_address <= w_add;
               o_data <= word_out(7 downto 0);
               w_add <= w_add + 1;
               word_out <= (others => '0');
               cur_state <= WAIT_W_WORD;                
           when WAIT_W_WORD =>
               if unsigned(cur_word)-1 = num_words then
                  cur_state <= DONE;
               else
                  got_input_buffer <=false;
                  cur_state <= READ_START;
                  ff_en <= '1';
               end if;                              
           when DONE =>
               o_done <= '1';
               cur_state <= START;
        end case;
    end if;
end process;
end behavioral;
        
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
        
entity ffd is
       port( 
               clk, en, rst : in std_logic;
               in1 : in std_logic;
               out1 : out std_logic := '0'
            );
end ffd;

architecture behavioral of ffd is
    begin
         process(clk, rst)
           begin
                if rising_edge(clk) then
                   if en = '1' then
                      if rst = '1' then
                          out1 <= '0';
                      else
                          out1 <= in1;
                      end if;
                   end if;
                end if;
         end process;
end behavioral;

