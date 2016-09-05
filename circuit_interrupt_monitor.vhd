library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

--------------------------------------------------------------------------------
-- The intent of this module is to observe and validate the data ready signal
-- originating from the AD7913. The signal is cyclic in nature and by default
-- occurs every 512 of the AD7913 ADC's clock cycles. The data ready signal is
-- pulsed low for 64 of those clock cycles. It is assumed that the clock being
-- driven to the ADC is operating at a frequency of 4.096 MHz. As such, the low
-- pulse period that occurs every 125 us will have a duration of 15.625 us.

--------------------------------------------------------------------------------

entity circuit_interrupt_monitor is
  generic(
    CLOCK_FREQUENCY_HZ : positive := 12000000
  );
  port(
    reset_n       : in    std_logic; -- 
    clock         : in    std_logic;
    data_ready_n  : in    std_logic; -- Active low signal. Asynchronous pulse coming from the AD7913's data ready line.
    data_ready    : out   std_logic -- Active high signal. Pulsed for one clock cycle when a *valid* interrupt has been received.
  );
end entity;



architecture behavioral of circuit_interrupt_monitor is

  constant NANOSECONDS_PER_SECOND : time := 1000000000 ns;
  constant CLOCK_CYCLE_PERIOD     : time := NANOSECONDS_PER_SECOND / CLOCK_FREQUENCY_HZ;

  -- Period is based on a 4.096 MHz ADC clock fresency, where 64 counts would
  -- equate to 15.625 us.
  constant DATA_READY_ASSERTION_PERIOD : time := 15.625 us;
  
  -- 
  constant COUNT_PER_DATA_READY_ASSERTION_PERIOD  : positive := integer(ceil(real(DATA_READY_ASSERTION_PERIOD / CLOCK_CYCLE_PERIOD)));
  
  type state_t is (
    WAIT_FOR_INTERRUPT_ASSERTION,
    WAIT_FOR_INTERRUPT_DEASSERTION
  );

  type signals_struct_t is
    record
      state : state_t;
      data_ready : std_logic;
      counter : natural range 0 to COUNT_PER_DATA_READY_ASSERTION_PERIOD;
    end record;

  signal sequential_outputs : signals_struct_t;
  signal sequential_inputs : signals_struct_t;

begin

  process(sequential_outputs, data_ready_n) is
  
    variable combinatorial_logic : signals_struct_t;
    
  begin

    data_ready          <= sequential_outputs.data_ready;
    
    combinatorial_logic := sequential_outputs;

    -- Deassert the data_ready pulse if it was previously asserted. 
    if sequential_outputs.data_ready = '1' then
    
      combinatorial_logic.data_ready        := '0';
      
    end if;
    
    combinatorial_logic.counter             := sequential_outputs.counter + 1;
    
    case sequential_outputs.state is
    
      -- Wait for the data_ready_n signal to go low then bring the counter out
      -- of reset. Proceed to the next state where the the module will wait for
      -- the data_ready_n signal to go high. 
      when WAIT_FOR_INTERRUPT_ASSERTION =>
      
        -- The data_ready_n signal is pulled up with a 10K resisitor. The only
        -- way it will go low is if it is actively driven low by the ADC.
        if data_ready_n = '0' then
        
          combinatorial_logic.state         := WAIT_FOR_INTERRUPT_DEASSERTION;
          
        else
        
          combinatorial_logic.counter       := 0;
          
        end if;
        
      when WAIT_FOR_INTERRUPT_DEASSERTION =>
        if data_ready_n = '1' then
        
          if sequential_outputs.counter = (COUNT_PER_DATA_READY_ASSERTION_PERIOD - 1) then
          
            combinatorial_logic.data_ready  := '1';  
            
          end if;
          
          combinatorial_logic.counter       := 0;
          combinatorial_logic.state         := WAIT_FOR_INTERRUPT_ASSERTION;
          
        end if;        
        -- The data_ready_n signal should be high for no more than the expected
        -- deassertion time. If it is then something went wrong and it can be assumed
        -- that the signal is no longer valid.
        
    end case;
    
    sequential_inputs <= combinatorial_logic;
    
  end process;

  process(reset_n, clock) is
  begin
    if reset_n = '0' then
    
      sequential_outputs.counter            <= 0;
      sequential_outputs.data_ready         <= '0';
      sequential_outputs.state              <= WAIT_FOR_INTERRUPT_ASSERTION;
      
    elsif rising_edge(clock) then
    
      sequential_outputs                    <= sequential_inputs;
      
    end if;
  end process;

end behavioral;
