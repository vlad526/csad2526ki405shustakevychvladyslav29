library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Передавач I2C master: передає один байт при імпульсі на `start_tx`.
--
-- Порти:
--   clk         : вхід системного тактового сигналу. Вся внутрішня послідовність
--                 синхронізована з цим сигналом. Повинен бути в тому ж домені,
--                 що і генератор тактового сигналу.
--   rst_n       : скидання активне низьким рівнем.
--   start_tx    : вхідний імпульс для початку передачі `data_in` (чутливий
--                 до фронту на наростаючому такті). Має бути активним мінімум один такт.
--   data_in     : байт для передачі, старший біт першим (MSB).
--   scl_rise    : однотактовий строб при наростаючому фронті SCL (використовується
--                 для зчитування SDA для ACK або вирівнювання змін даних по спаду SCL).
--   scl_fall    : однотактовий строб при спадаючому фронті SCL (для встановлення наступного біта).
--   sda_in      : зчитане значення лінії SDA (для зчитування ACK) від верхнього рівня.
--   sda_out     : керування виходом SDA: '0' для притягування до землі, 'Z' для відпускання (open-drain).
--   busy        : '1' під час процесу передачі.
--   ack_received: зчитаний біт ACK після передачі байту (0 = ACK, 1 = NACK).
--   done        : однотактовий імпульс, що сигналізує завершення передачі байту та зчитування ACK.
entity i2c_master_tx is
  port (
    clk         : in  std_logic;  -- system clock (same domain as clock generator)
    rst_n       : in  std_logic;
    start_tx    : in  std_logic;  -- pulse to start transmitting data_in
    data_in     : in  std_logic_vector(7 downto 0);
    scl_rise    : in  std_logic;  -- strobe: SCL rising
    scl_fall    : in  std_logic;  -- strobe: SCL falling
    sda_in      : in  std_logic;  -- sample SDA for ACK
    sda_out     : out std_logic;  -- drive SDA: '0' to pull low, 'Z' to release
    busy        : out std_logic;  -- high while transaction in progress
    ack_received: out std_logic;  -- sampled ACK (0 = ACK, 1 = NACK)
    done        : out std_logic   -- pulse when byte tx + ack complete
  );
end entity;

architecture rtl of i2c_master_tx is
  -- Регістри внутрішнього автомату станів
  type t_state is (IDLE, START, SEND_BIT, RECV_ACK, FINISH);
  signal state : t_state := IDLE; -- поточний стан FSM

  -- лічильник бітів: індекс поточного біта, що передається (7 downto 0)
  signal bit_cnt : integer range 0 to 7 := 0;

  -- зсувний регістр зберігає байт, що передається, старший біт першим
  signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');

  -- керування лінією SDA: '0' для притягування до землі, 'Z' для відпускання лінії
  signal sda_drive : std_logic := 'Z';

  -- регістри для зчитаного значення ACK та імпульсу завершення
  signal ack_r : std_logic := '1';
  signal done_r: std_logic := '0';
begin
  sda_out <= sda_drive;
  busy <= '1' when state /= IDLE else '0';
  ack_received <= ack_r;
  done <= done_r;

  process(clk, rst_n)
  begin
    if rst_n = '0' then
      state <= IDLE;
      shift_reg <= (others => '0');
      bit_cnt <= 0;
      sda_drive <= 'Z';
      ack_r <= '1';
      done_r <= '0';
    elsif rising_edge(clk) then
      done_r <= '0';
      if state = IDLE then
        if start_tx = '1' then
          shift_reg <= data_in;
          bit_cnt <= 7;
          state <= START;
        end if;
      elsif state = START then
        -- prepare to drive first bit on SCL falling edge
        if scl_fall = '1' then
          sda_drive <= shift_reg(bit_cnt);
          state <= SEND_BIT;
        end if;
      elsif state = SEND_BIT then
        -- on SCL rising we sample nothing, on falling we prepare next bit
        if scl_fall = '1' then
          if bit_cnt = 0 then
            sda_drive <= 'Z'; -- release SDA for ACK bit
            state <= RECV_ACK;
          else
            bit_cnt <= bit_cnt - 1;
            sda_drive <= shift_reg(bit_cnt - 1);
          end if;
        end if;
      elsif state = RECV_ACK then
        -- sample ACK on SCL rising
        if scl_rise = '1' then
          ack_r <= sda_in; -- '0' means ACK
          state <= FINISH;
        end if;
      elsif state = FINISH then
        done_r <= '1';
        state <= IDLE;
      end if;
    end if;
  end process;
end architecture;
