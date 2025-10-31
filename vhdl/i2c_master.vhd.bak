library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Верхній рівень I2C Master
--
-- Призначення:
--   Забезпечує просту реалізацію I2C master, яка може виконувати одиночні
--   операції запису або читання байту за 7-бітною адресою slave-пристрою.
--   Цей верхній рівень містить генератор тактового сигналу, передавач та
--   приймач і координує послідовність start/адреса/дані/stop через невеликий FSM.
--
-- Порти (зовнішній інтерфейс):
--   clk    : системний тактовий сигнал для логіки master
--   rst_n  : скидання активне низьким рівнем
--   start  : імпульс для початку транзакції (адреса + опціональні дані)
--   addr   : 7-бітна I2C адреса slave-пристрою
--   rw     : прапор читання/запису ('0'=запис, '1'=читання)
--   data_in: байт для відправки при операції запису
--   data_out: байт, отриманий під час операцій читання
--   busy   : вказує, що master зайнятий виконанням транзакції
--
-- Фізичний ввід/вивід:
--   sda : двонаправлена лінія SDA з відкритим стоком (потрібні зовнішні підтяжки)
--   scl : лінія SCL, що генерується master (семантика відкритого стоку через sda)
entity i2c_master is
  generic (
    PRESCALER : natural := 250
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    start    : in  std_logic;  -- start a write transaction (for demo)
    addr     : in  std_logic_vector(6 downto 0); -- 7-bit address
    rw       : in  std_logic;  -- '0' = write, '1' = read
    data_in  : in  std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0);
    busy     : out std_logic;

    -- I2C physical lines (open-drain semantics)
    sda      : inout std_logic;
    scl      : out   std_logic
  );
end entity;

architecture rtl of i2c_master is
  -- SCL signals provided by the clock generator
  signal scl_sig, scl_rise, scl_fall : std_logic;

  -- Enable signal for the clock generator (allows pausing SCL)
  signal clk_enable : std_logic := '1';

  -- Внутрішнє керування SDA для реалізації поведінки відкритого стоку
  -- від внутрішніх драйверів: '0' для притягування лінії SDA до землі,
  -- 'Z' для відпускання лінії, дозволяючи зовнішній підтяжці підняти її вгору.
  signal sda_drive : std_logic := 'Z';
  -- sda_in зчитує зовнішню лінію SDA для ACK та отриманих даних
  signal sda_in    : std_logic;

  -- instantiate clock generator
  component i2c_master_clock
    generic (PRESCALER : natural := 250);
    port (
      clk      : in std_logic;
      rst_n    : in std_logic;
      enable   : in std_logic;
      scl      : out std_logic;
      scl_rise : out std_logic;
      scl_fall : out std_logic
    );
  end component;

  -- Tx / Rx components
  component i2c_master_tx
    port (
      clk         : in  std_logic;
      rst_n       : in  std_logic;
      start_tx    : in  std_logic;
      data_in     : in  std_logic_vector(7 downto 0);
      scl_rise    : in  std_logic;
      scl_fall    : in  std_logic;
      sda_in      : in  std_logic;
      sda_out     : out std_logic;
      busy        : out std_logic;
      ack_received: out std_logic;
      done        : out std_logic
    );
  end component;

  component i2c_master_rx
    port (
      clk       : in  std_logic;
      rst_n     : in  std_logic;
      start_rx  : in  std_logic;
      scl_rise  : in  std_logic;
      sda_in    : in  std_logic;
      data_out  : out std_logic_vector(7 downto 0);
      data_valid: out std_logic;
      busy      : out std_logic
    );
  end component;

  signal tx_sda_out : std_logic;
  signal tx_busy     : std_logic;
  signal tx_ack      : std_logic;
  signal tx_done     : std_logic;

  signal rx_data     : std_logic_vector(7 downto 0);
  signal rx_valid    : std_logic;
  signal rx_busy_sig : std_logic;

  -- Простий FSM master, що керує послідовністю транзакцій високого рівня:
  --   IDLE       - очікування запиту `start`
  --   START_COND - встановлення SDA в низький рівень при високому SCL для генерації START
  --   SEND_ADDR  - відправка 7-бітної адреси + біт R/W через блок Tx
  --   SEND_DATA  - відправка байту(ів) даних через блок Tx
  --   RECV_DATA  - прийом байту від slave-пристрою через блок Rx
  --   STOP_COND  - відпускання SDA при високому SCL для генерації STOP
  --   DONE       - завершення та повернення до IDLE
  type t_state is (IDLE, START_COND, SEND_ADDR, SEND_DATA, RECV_DATA, STOP_COND, DONE);
  signal state : t_state := IDLE;

  -- address + R/W encoded into an 8-bit value for the transmitter
  signal addr_rw : std_logic_vector(7 downto 0);

  -- pulses to start the lower-level Tx/Rx modules (generated for one cycle)
  signal start_tx_pulse : std_logic := '0';
  signal start_rx_pulse : std_logic := '0';

  -- captured output byte from read operations
  signal data_out_r : std_logic_vector(7 downto 0) := (others => '0');

begin
  -- Implement open-drain behavior on the top-level SDA pin by driving
  -- '0' when any internal driver pulls low, otherwise release ('Z') and rely
  -- on external pull-ups.
  sda <= '0' when sda_drive = '0' else 'Z';
  -- Sampled SDA value available to internal units
  sda_in <= sda;
  -- Expose generated SCL to the outside
  scl <= scl_sig;

  U_CLK: i2c_master_clock
    generic map (PRESCALER => PRESCALER)
    port map (clk => clk, rst_n => rst_n, enable => clk_enable, scl => scl_sig, scl_rise => scl_rise, scl_fall => scl_fall);

  U_TX: i2c_master_tx
    port map (clk => clk, rst_n => rst_n, start_tx => start_tx_pulse, data_in => data_in,
              scl_rise => scl_rise, scl_fall => scl_fall, sda_in => sda_in, sda_out => tx_sda_out,
              busy => tx_busy, ack_received => tx_ack, done => tx_done);

  U_RX: i2c_master_rx
    port map (clk => clk, rst_n => rst_n, start_rx => start_rx_pulse, scl_rise => scl_rise,
              sda_in => sda_in, data_out => rx_data, data_valid => rx_valid, busy => rx_busy_sig);

  -- Головний FSM: координує START, передачу адреси/даних та STOP.
  -- Примітка: це спрощена послідовність, придатна для передачі одного байту
  -- в демонстраційних сценаріях. Реальне використання повинно додавати
  -- таймаути, підтримку багатобайтових передач та обробку помилок.
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      sda_drive <= 'Z';
      state <= IDLE;
      start_tx_pulse <= '0';
      start_rx_pulse <= '0';
      data_out_r <= (others => '0');
    elsif rising_edge(clk) then
      -- default: clear one-cycle pulses
      start_tx_pulse <= '0';
      start_rx_pulse <= '0';
      case state is
        when IDLE =>
          -- wait for external request to start a transaction
          if start = '1' then
            state <= START_COND;
          end if;
        when START_COND =>
          -- Generate I2C START condition: SDA low while SCL is high.
          sda_drive <= '0';
          -- Wait for one falling edge of SCL to align bit transfers
          if scl_fall = '1' then
            addr_rw <= addr & rw; -- compose 7-bit address + R/W bit
            start_tx_pulse <= '1';
            state <= SEND_ADDR;
          end if;
        when SEND_ADDR =>
          -- drive SDA according to TX module when busy; otherwise release
          sda_drive <= tx_sda_out when tx_busy = '1' or tx_done = '0' else 'Z';
          if tx_done = '1' then
            if rw = '0' then
              -- write: send data next
              start_tx_pulse <= '1';
              state <= SEND_DATA;
            else
              -- read: start RX unit to capture incoming byte
              start_rx_pulse <= '1';
              state <= RECV_DATA;
            end if;
          end if;
        when SEND_DATA =>
          sda_drive <= tx_sda_out when tx_busy = '1' or tx_done = '0' else 'Z';
          if tx_done = '1' then
            state <= STOP_COND;
          end if;
        when RECV_DATA =>
          -- release SDA and wait for RX to assert data_valid
          sda_drive <= 'Z';
          if rx_valid = '1' then
            data_out_r <= rx_data;
            state <= STOP_COND;
          end if;
        when STOP_COND =>
          -- Generate STOP: release SDA while SCL is high, then wait for rising edge
          sda_drive <= 'Z';
          if scl_rise = '1' then
            state <= DONE;
          end if;
        when DONE =>
          -- transaction completed
          state <= IDLE;
      end case;
    end if;
  end process;

  data_out <= data_out_r;
  busy <= '1' when state /= IDLE else '0';

end architecture;
