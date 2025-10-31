library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Приймач I2C master: зчитує SDA на наростаючому фронті SCL та збирає один байт
-- при імпульсі на `start_rx`.
--
-- Порти:
--   clk        : вхід системного тактового сигналу (той самий домен, що й генератор тактів)
--   rst_n      : скидання активне низьким рівнем
--   start_rx   : імпульс для початку захоплення 8 бітів з SDA на послідовних
--                наростаючих фронтах SCL
--   scl_rise   : строб, активний протягом одного системного такту при наростаючому
--                фронті SCL (використовується для зчитування SDA)
--   sda_in     : поточний рівень SDA, зчитаний на верхньому рівні
--   data_out   : зібраний байт (старший біт першим)
--   data_valid : однотактовий імпульс, що сигналізує про готовність data_out
--   busy       : '1' під час процесу прийому
entity i2c_master_rx is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    start_rx  : in  std_logic;  -- pulse to start receiving one byte
    scl_rise  : in  std_logic;  -- strobe: SCL rising
    sda_in    : in  std_logic;  -- sampled SDA
    data_out  : out std_logic_vector(7 downto 0);
    data_valid: out std_logic;  -- pulse when data_out valid
    busy      : out std_logic
  );
end entity;

architecture rtl of i2c_master_rx is
  -- Автомат станів та внутрішні регістри:
  type t_state is (IDLE, RECV_BIT, FINISH);
  signal state: t_state := IDLE; -- стан FSM

  -- лічильник бітів відраховує від 7 до 0 при зчитуванні бітів
  signal bit_cnt: integer range 0 to 7 := 7;

  -- зсувний регістр накопичує зчитані біти (MSB в індексі 7)
  signal shift_reg: std_logic_vector(7 downto 0) := (others => '0');

  -- data_valid_r генерує імпульс на зовнішньому виході data_valid
  signal data_valid_r: std_logic := '0';
begin
  data_out <= shift_reg;
  data_valid <= data_valid_r;
  busy <= '1' when state /= IDLE else '0';

  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state <= IDLE;
      shift_reg <= (others => '0');
      bit_cnt <= 7;
      data_valid_r <= '0';
    elsif rising_edge(clk) then
      data_valid_r <= '0';
      if state = IDLE then
        if start_rx = '1' then
          bit_cnt <= 7;
          state <= RECV_BIT;
        end if;
      elsif state = RECV_BIT then
        if scl_rise = '1' then
          shift_reg(bit_cnt) <= sda_in;
          if bit_cnt = 0 then
            state <= FINISH;
          else
            bit_cnt <= bit_cnt - 1;
          end if;
        end if;
      elsif state = FINISH then
        data_valid_r <= '1';
        state <= IDLE;
      end if;
    end if;
  end process;
end architecture;
