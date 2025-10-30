library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Простий дільник частоти для генерації SCL сигналу I2C master.
--
-- Призначення:
--   Генерує внутрішній SCL сигнал з більш швидкого системного тактового сигналу.
--   Модуль виробляє push-pull SCL вихід (верхній рівень повинен перетворити
--   його в open-drain за потреби) та два імпульси шириною в один такт:
--     * scl_rise - імпульс при переході SCL з низького в високий рівень
--     * scl_fall - імпульс при переході SCL з високого в низький рівень
--
-- Загальні параметри:
--   PRESCALER - кількість тактів системного годинника на півперіод SCL
--
-- Порти:
--   clk      : вхід системного тактового сигналу (швидкий домен)
--   rst_n    : синхронний скид активний низьким рівнем
--   enable   : коли '1' генерація SCL активна; коли '0' SCL утримується високим
--   scl      : генерований SCL вихід (push-pull)
--   scl_rise : імпульс при наростаючому фронті SCL (шириною один такт)
--   scl_fall : імпульс при спадаючому фронті SCL (шириною один такт)
entity i2c_master_clock is
  generic (
    PRESCALER : natural := 250  -- divide sys_clk to get SCL; adjust to get desired frequency
  );
  port (
    clk      : in  std_logic;
    rst_n    : in  std_logic;
    enable   : in  std_logic := '1';
    scl      : out std_logic;       -- generated SCL (push-pull); top-level can implement open-drain
    scl_rise : out std_logic;       -- pulse on rising edge of scl (one clk wide)
    scl_fall : out std_logic        -- pulse on falling edge of scl (one clk wide)
  );
end entity;

architecture rtl of i2c_master_clock is
  -- Внутрішній лічильник для ділення системного тактового сигналу.
  -- Ширина щедра; ви можете зменшити її відповідно до максимального
  -- значення PRESCALER вашої платформи.
  signal cnt    : unsigned(31 downto 0) := (others => '0');

  -- Регістр SCL зберігає поточний стан генерованого тактового сигналу (0 або 1).
  -- Починається з високого рівня для представлення стану очікування шини I2C
  -- (SCL відпущений/підтягнутий вгору).
  signal scl_reg: std_logic := '1';
begin
  -- Основний дільник частоти: збільшує cnt на кожному такті системного
  -- годинника; при досягненні PRESCALER-1 перемикає SCL та генерує
  -- одиночний імпульс на відповідному виході (scl_rise або scl_fall).
  -- Вхід enable дозволяє основному FSM призупиняти генерацію SCL за потреби.
  process(clk, rst_n)
  begin
    if rst_n = '0' then
      cnt <= (others => '0');
      scl_reg <= '1';
      scl_rise <= '0';
      scl_fall <= '0';
    elsif rising_edge(clk) then
      -- default: clear strobes every cycle
      scl_rise <= '0';
      scl_fall <= '0';
      if enable = '1' then
        if cnt = PRESCALER - 1 then
          -- Half-period elapsed: toggle SCL
          cnt <= (others => '0');
          scl_reg <= not scl_reg;
          -- Emit a pulse on the appropriate edge strobe. Note that we check
          -- the previous value of scl_reg to determine which edge just
          -- occurred.
          if scl_reg = '0' then
            -- prior value 0 -> now 1 => rising edge
            scl_rise <= '1';
          else
            -- prior value 1 -> now 0 => falling edge
            scl_fall <= '1';
          end if;
        else
          cnt <= cnt + 1;
        end if;
      end if;
    end if;
  end process;

  scl <= scl_reg;
end architecture;
