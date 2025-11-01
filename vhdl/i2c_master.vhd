-- Верхній рівень I2C Master
--
-- Призначення:
--   Забезпечити просту реалізацію I2C master, яка може виконувати одиничну
--   операцію запису або читання байту до 7-бітної адреси slave-пристрою.
--   Верхній рівень інстанціює генератор SCL, блок передачі (Tx) та блок прийому (Rx)
--   та координує послідовності START/адреса/дані/STOP через невеликий FSM.
--
-- Фізичні лінії:
--   sda : двонаправлена лінія SDA з відкритим стоком (потрібні зовнішні підтяжки)
--   scl : лінія SCL, що генерується master
entity i2c_master is
  generic (
    PRESCALER : natural := 250
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
  start    : in  std_logic;  -- імпульс початку транзакції (для демонстрації)
  addr     : in  std_logic_vector(6 downto 0); -- 7-бітна адреса
  rw       : in  std_logic;  -- '0' = запис, '1' = читання
    data_in  : in  std_logic_vector(7 downto 0);
    data_out : out std_logic_vector(7 downto 0);
    busy     : out std_logic;

    -- Фізичні лінії I2C (поведінка open-drain (відкритий стік) реалізується через SDA)
    sda      : inout std_logic;
    scl      : out   std_logic
  );
end entity;

architecture rtl of i2c_master is
  -- Сигнали SCL, що надає генератор тактового сигналу
  signal scl_sig, scl_rise, scl_fall : std_logic;

  -- Сигнал дозволу для генератора SCL (дозволяє призупиняти SCL)
  signal clk_enable : std_logic := '1';

  -- Внутрішнє керування SDA для реалізації open-drain: '0' притягує лінію,
  -- 'Z' відпускає лінію і дозволяє зовнішній підтяжці підняти її.
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
  --   IDLE, START_COND, SEND_ADDR, SEND_DATA, RECV_DATA, STOP_COND, DONE
  type t_state is (IDLE, START_COND, SEND_ADDR, SEND_DATA, RECV_DATA, STOP_COND, DONE);
  signal state : t_state := IDLE;

  -- address + R/W encoded into an 8-bit value for the transmitter
  signal addr_rw : std_logic_vector(7 downto 0);

  -- однотактові імпульси для запуску нижчого рівня Tx/Rx (генеруються на один такт)
  signal start_tx_pulse : std_logic := '0';
  signal start_rx_pulse : std_logic := '0';

  -- захоплений байт, отриманий під час операцій читання
  signal data_out_r : std_logic_vector(7 downto 0) := (others => '0');

begin
  -- Реалізація поведінки open-drain на верхній лінії SDA: якщо будь-який
  -- внутрішній драйвер тягне лінію в '0' — виводимо '0', інакше відпускаємо
  -- ('Z') і покладаємось на зовнішню підтяжку вгору.
  sda <= '0' when sda_drive = '0' else 'Z';
  -- Значення SDA доступне внутрішнім модулям
  sda_in <= sda;
  -- Виводимо згенерований SCL назовні
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
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      sda_drive <= 'Z';
      state <= IDLE;
      start_tx_pulse <= '0';
      start_rx_pulse <= '0';
      data_out_r <= (others => '0');
    elsif rising_edge(clk) then
  -- скидаємо однотактові імпульси за замовчуванням
  start_tx_pulse <= '0';
  start_rx_pulse <= '0';
      case state is
        when IDLE =>
          -- очікуємо зовнішнього запиту на початок транзакції
          if start = '1' then
            state <= START_COND;
          end if;
        when START_COND =>
          -- Генеруємо START: SDA низький при високому SCL
          sda_drive <= '0';
          -- Чекаємо одного падіння SCL перед початком передачі бітів
          if scl_fall = '1' then
            addr_rw <= addr & rw; -- сформувати 7-бітну адресу + біт R/W
            start_tx_pulse <= '1';
            state <= SEND_ADDR;
          end if;
        when SEND_ADDR =>
          -- Керуємо SDA відповідно до виходу TX, коли TX зайнятий; інакше відпускаємо
          if (tx_busy = '1' or tx_done = '0') then
            sda_drive <= tx_sda_out;
          else
            sda_drive <= 'Z';
          end if;
          
          if tx_done = '1' then
            if rw = '0' then
              -- запис: відправити наступний байт даних
              start_tx_pulse <= '1';
              state <= SEND_DATA;
            else
              -- читання: запустити RX для прийому байту
              start_rx_pulse <= '1';
              state <= RECV_DATA;
            end if;
          end if;
        when SEND_DATA =>
          -- Передача даних через TX; відпускати SDA коли TX завершив байт
          if (tx_busy = '1' or tx_done = '0') then
            sda_drive <= tx_sda_out;
          else
            sda_drive <= 'Z';
          end if;
          
          if tx_done = '1' then
            state <= STOP_COND;
          end if;
        when RECV_DATA =>
          -- Відпускаємо SDA та чекаємо, поки RX встановить data_valid
          sda_drive <= 'Z';
          if rx_valid = '1' then
            data_out_r <= rx_data;
            state <= STOP_COND;
          end if;
        when STOP_COND =>
          -- Генеруємо STOP: відпускаємо SDA при високому SCL, потім чекаємо підйому SCL
          sda_drive <= 'Z';
          if scl_rise = '1' then
            state <= DONE;
          end if;
        when DONE =>
          -- транзакція завершена
          state <= IDLE;
      end case;
    end if;
  end process;

  -- Примітка: цю частину можна рефакторити (наприклад, логіку в 'process' або
  -- використання 'when/else' замінити іншою структурою за потреби).
  data_out <= data_out_r;
  busy <= '1' when state /= IDLE else '0';

end architecture;

