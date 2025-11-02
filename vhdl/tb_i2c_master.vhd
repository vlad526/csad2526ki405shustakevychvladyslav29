library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Тестбенч для i2c_master
--
-- Призначення:
--   Генерує тактовий сигнал і скидання, подає тестові дані на передавач (Tx)
--   і імітує простий slave для перевірки поведінки приймача (Rx).
--
-- Зауваження:
--   Це демонстраційний тестбенч; для повного тестування I2C (таймаути,
--   багатобайтові передачі, коректні ACK/NACK) потрібна детальніша модель slave.

entity tb_i2c_master is
end entity;

architecture sim of tb_i2c_master is
  -- Тактові та контрольні сигнали тестбенчу
  signal clk    : std_logic := '0';
  signal rst_n  : std_logic := '0';

  -- Інтерфейс до DUT (Device Under Test)
  signal start   : std_logic := '0';
  signal addr    : std_logic_vector(6 downto 0) := (others => '0');
  signal rw      : std_logic := '0';
  signal data_in : std_logic_vector(7 downto 0) := (others => '0');
  signal data_out: std_logic_vector(7 downto 0);
  signal busy    : std_logic;

  -- Фізичні лінії I2C (тестова шина)
  signal sda_tb : std_logic := 'Z'; -- сигнал, підключений до порту inout DUT
  signal scl    : std_logic;

  -- Параметри симуляції
  constant CLK_PERIOD_NS : time := 20 ns; -- приблизно 50 MHz

  -- Сигнали для простого slave-емулятора
  signal slave_active : std_logic := '0';
  signal slave_byte   : std_logic_vector(7 downto 0) := x"A5"; -- байт, який надсилає slave під час читання
  signal slave_bit_idx: integer range 0 to 7 := 7;
  signal tb_done      : std_logic := '0';

begin
  ------------------------------------------------------------------
  -- Інстанція DUT
  ------------------------------------------------------------------
  UUT: entity work.i2c_master
    generic map (PRESCALER => 50) -- занижено для швидшої симуляції
    port map (
      clk => clk,
      rst_n => rst_n,
      start => start,
      addr => addr,
      rw => rw,
      data_in => data_in,
      data_out => data_out,
      busy => busy,
      sda => sda_tb,
      scl => scl
    );

  ------------------------------------------------------------------
  -- Генератор тактового сигналу
  ------------------------------------------------------------------
  clk_gen: process
  begin
    while now < 200 ms loop
      clk <= '0';
      wait for CLK_PERIOD_NS/2;
      clk <= '1';
      wait for CLK_PERIOD_NS/2;
    end loop;
    wait;
  end process;

  ------------------------------------------------------------------
  -- Скидання та стимули
  ------------------------------------------------------------------
  stim_proc: process
  begin
  -- початкове скидання
  rst_n <= '0';
    wait for 200 ns;
    rst_n <= '1';
    wait for 200 ns;

  -- Тест 1: запис одного байта (запис)
  addr <= "0101010"; -- приклад 7-бітної адреси
  rw <= '0'; -- запис
    data_in <= x"5A";
  wait for CLK_PERIOD_NS; -- вирівняти з тактом
  -- сигнал початку — однотактовий імпульс
    start <= '1';
    wait for CLK_PERIOD_NS;
    start <= '0';

  -- чекати на завершення транзакції
  wait until busy = '1';
  wait until busy = '0';
  report "Запис завершено, переходжу до тесту читання";
    wait for 1 us;

  -- Тест 2: читання одного байта (читання)
  addr <= "0101010";
  rw <= '1'; -- читання
    data_in <= (others => '0');

  -- Підготувати slave-емулятор: активувати через невеликий запас, щоб
  -- master встиг пройти фазу адреси.
  slave_byte <= x"A5";
  wait for 200 ns;
  slave_active <= '1';

    wait for CLK_PERIOD_NS;
    start <= '1';
    wait for CLK_PERIOD_NS;
    start <= '0';

  -- дочекатись завершення операції
  wait until busy = '1';
  wait until busy = '0';
  wait for 500 ns; -- невелика пауза для стабілізації

  report "Читання завершено, data_out = " & to_hstring(data_out);
  tb_done <= '1';

    wait;
  end process;

  ------------------------------------------------------------------
  -- Простий slave-емулятор для перевірки Rx
  -- Логіка: коли active, на падінні SCL виставляє відповідний біт байта на SDA
  ------------------------------------------------------------------
  slave_proc: process
  begin
    wait until slave_active = '1';

    -- Ініціалізуємо індекс біта перед передачею
    slave_bit_idx <= 7;

    -- Чекати початку роботи SCL
    wait until scl = '0';
    wait for 1 ns;

    -- Передаватимемо біти при кожному падінні SCL (щоб вони були стабільні до наступного підйому)
    while slave_active = '1' loop
      wait until scl = '0';
      -- Встановити біт для майбутнього зчитування при наступному підйомі SCL
      sda_tb <= slave_byte(slave_bit_idx);
      wait until scl = '1'; -- master зчитає на підйомі
      -- Після підйому відпустити або підготувати наступний біт на падінні
      if slave_bit_idx = 0 then
        -- Завершили передачу 8 бітів
        slave_active <= '0';
        sda_tb <= 'Z';
        exit;
      else
        slave_bit_idx <= slave_bit_idx - 1;
        -- На падінні налаштуємо наступний біт
        wait until scl = '0';
      end if;
    end loop;
    wait;
  end process;

  ------------------------------------------------------------------
  -- Завершення симуляції
  ------------------------------------------------------------------
  finish_proc: process
  begin
    wait until tb_done = '1';
    wait for 1 us;
    report "Testbench finished";
    wait;
  end process;

end architecture;

