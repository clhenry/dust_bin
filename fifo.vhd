library ieee;
use ieee.std_logic_1164.all;

entity fifo is
  generic(
    WIDTH   : positive := 8; -- Number of bits in a FIFO word.
    DEPTH   : positive := 8-- Number of words that the FIFO is capable of storing.
  );
  port(
    reset_n : in  std_logic; -- Active low signal. Assert to reset the module.
    clock   : in  std_logic; -- Clock signal clocking the module's sequential elements.
    enqueue : in  std_logic; -- Active high signal. Assert to write 'back' .
    dequeue : in  std_logic; -- Active high signal. Assert to
    back    : in  std_logic_vector(WIDTH - 1 downto 0); -- If 'full' is not asserted then these signals must driven before asserting 'enqueue' to store valid data in the FIFO.
    front   : out std_logic_vector(WIDTH - 1 downto 0); -- If 'empty' is not asserted then these signals represent valid data at the front of the FIFO.
    full    : out std_logic; -- Active high signal. The module asserts this signal when all the available word locations have been written to.
    empty   : out std_logic -- Active high signal. The module asserts this signal on reset or when all the words written to the fifo have been dequeued.
  );
end entity;

architecture rtl of fifo is

  constant ZERO_FILLED_WORD : std_logic_vector(WIDTH - 1 downto 0) := (others => '0');

  type memory_t is array(DEPTH - 1 downto 0) of std_logic_vector(WIDTH - 1 downto 0);

  type signals_struct_t is
    record
      memory  : memory_t;
      index   : natural range 0 to (DEPTH - 1); -- Points to the next available memory location in the FIFO if the FIFO is not full.
      full    : std_logic;
      empty   : std_logic;
    end record;

  signal sequential_inputs : signals_struct_t;
  signal sequential_outputs : signals_struct_t;

begin

  process(sequential_outputs, enqueue, dequeue, back) is
  
    variable combinatorial_logic : signals_struct_t;
  
  begin
  
    front <= sequential_outputs.memory(0);
    full <= sequential_outputs.full;
    empty <= sequential_outputs.empty;
    
    combinatorial_logic := sequential_outputs;
    
    ----------------------------------------------------------------------------
    -- Begin FIFO Read Request
    ----------------------------------------------------------------------------
    if dequeue = '1' then
    
      -- This is a read request so in the event that the FIFO was previously
      -- marked full it will no longer be full after the request has completed
      -- and as such the 'full' bit can be cleared.      
      if sequential_outputs.full = '1' then
      
        combinatorial_logic.full := '0';
        
      end if;
      
      -- As long as the FIFO was not previously marked empty then it can be read
      -- from.
      if sequential_outputs.empty = '0' then
      
        -- The word that was present on ther 'front' port of the FIFO
        -- corresponded to the data that was in memory word 0. The dequeue
        -- operation drops that word and shifts the proceeding words down in the
        -- direction of memory word 0. The memory word at the back of the FIFO
        -- is filled in with zeros.
        combinatorial_logic.memory := ZERO_FILLED_WORD & sequential_outputs.memory(DEPTH - 1 downto 1);
      
        -- 'Index' was already pointing to the last valid word in the FIFO. So
        -- after the last word has been de-queued then the FIFO nust be empty.
        if sequential_outputs.index = 0 then
        
          combinatorial_logic.empty := '1';
          
        -- Decrement 'index' so it points to the next valid word in the FIFO.
        else
        
          combinatorial_logic.index := sequential_outputs.index - 1;
          
        end if;
      
      end if;
    
    end if;
    ----------------------------------------------------------------------------
    -- End FIFO Read Request
    ----------------------------------------------------------------------------
    
    ----------------------------------------------------------------------------
    -- Begin FIFO Write Request Handler
    ----------------------------------------------------------------------------
    if enqueue = '1' then
    
      -- If there is a write then clear the 'empty' bit.
      if sequential_outputs.empty = '1' then
      
        combinatorial_logic.empty                             := '0';
        
      end if;
    
      -- Allow writing to the FIFO ONLY if it is NOT full.
      if sequential_outputs.full = '0' then
      
        -- Write the data present on the 'back' port to the memory location
        -- pointed to by the 'index' signal.
        combinatorial_logic.memory(sequential_outputs.index)  := back;
        
        if sequential_outputs.index = (DEPTH - 1) then
        
          combinatorial_logic.full                            := '1';
          
        else
        
          combinatorial_logic.index                           := sequential_outputs.index + 1;
        
        end if;
      
      end if;
    
    end if;
    ----------------------------------------------------------------------------
    -- End FIFO Write Request Handler
    ----------------------------------------------------------------------------
  
    sequential_inputs <= combinatorial_logic;
  
  end process;

  process(reset_n, clock) is
  begin
  
    if reset_n = '0' then
    
      for i in 0 to DEPTH - 1 loop

        sequential_outputs.memory(i) <= (others => '0');

      end loop;

      sequential_outputs.index <= 0;
      sequential_outputs.full <= '0';
      sequential_outputs.empty <= '1';
    
    elsif rising_edge(clock) then
    
      sequential_outputs <= sequential_inputs;
    
    end if;
    
  end process;


end rtl;
