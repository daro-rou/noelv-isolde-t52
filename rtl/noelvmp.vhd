------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023,        Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.cfgmap.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;
    SIMULATION              : integer := 0
    -- pragma translate_off
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
    );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk         : in    std_ulogic;
    -- UART
    uart_rx     : in    std_ulogic; 
    uart_tx     : out   std_ulogic;
    uart_ctsn   : in    std_ulogic; 
    uart_rtsn   : out   std_ulogic; 
    -- Debug UART
    duart_rx    : in    std_ulogic; 
--    duart_tx    : out   std_ulogic;
    -- Debug
    dmen        : in    std_ulogic; 
    dmbreak     : in    std_ulogic; 
--    dmreset     : out   std_ulogic; 
    cpu0errn    : out   std_ulogic 
    );
end;

architecture rtl of noelvmp is
  constant OEPOL        : integer := padoen_polarity(padtech);
  constant BOARD_FREQ   : integer := 100000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  -------------------------------------
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  -- Clocks and Reset
  signal clkm           : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;
  signal rstn           : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;
  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal resetn         : std_ulogic;

  -- UART
  signal luart_rx       : std_logic_vector(0 downto 0);
  signal luart_ctsn     : std_logic_vector(0 downto 0);
  signal luart_tx       : std_logic_vector(0 downto 0);
  signal luart_rtsn     : std_logic_vector(0 downto 0);
  signal lduart_rx      : std_ulogic;
--  signal lduart_tx      : std_ulogic;
  -- GPIO
  -- signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- JTAG
  signal tck, tms, tdi, tdo : std_ulogic;
  -- Ethernet
--  signal ethi           : eth_in_type;
--  signal etho           : eth_out_type;
--  signal eth_apbi       : apb_slv_in_type;
--  signal eth_apbo       : apb_slv_out_type := apb_none;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;
  --  signal mem_ahbsi0     : ahb_slv_in_type;
  --  signal mem_ahbso0     : ahb_slv_out_type;
  --  signal mem_apbi0      : apb_slv_in_type;
  --  signal mem_apbo0      : apb_slv_out_type;
  --  signal rom_ahbsi1     : ahb_slv_in_type;
  --  signal rom_ahbso1     : ahb_slv_out_type;

  signal ldmen          : std_logic;
  signal ldmbreak       : std_logic;
--  signal ldmreset       : std_logic;
  signal lcpu0errn      : std_logic;
begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= resetn;

  -- Clocks
  clk_pad : clkpad
    generic map (tech => padtech)
    port map (clk, lclk);
  clkgen0 : clkgen        -- clock generator
    generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, 0,
                 CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
    port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);

  reset_pad : inpad
    generic map (tech => padtech)
    port map (reset, resetn);

  lock <= cgo.clklock;

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  core0 : entity work.noelvcore
  generic map (
    fabtech     => CFG_FABTECH,
    memtech     => CFG_MEMTECH,
    padtech     => CFG_PADTECH,
    clktech     => CFG_CLKTECH,
    cpu_freq    => CPU_FREQ,
    devid       => NOELV_SOC,
    disas       => disas)
  port map (
    -- Clock & reset
    clkm        => clkm, 
    resetn      => resetn,
    lock        => lock,
    rstno       => rstn,
    -- misc
    dmen        => ldmen,
    dmbreak     => ldmbreak,
--    dmreset     => ldmreset,
    cpu0errn    => lcpu0errn,
    -- GPIO
    -- gpio_i      => gpio_i,
    -- gpio_o      => gpio_o,
    -- gpio_oe     => gpio_oe,
    -- UART
    uart_rx     => luart_rx,
    uart_ctsn   => luart_ctsn,
    uart_tx     => luart_tx,
    uart_rtsn   => luart_rtsn,
    -- Memory controller
    mem_aximi   => mem_aximi,
    mem_aximo   => mem_aximo,
    --  mem_ahbsi0  => mem_ahbsi0,
    --  mem_ahbso0  => mem_ahbso0,
    --  mem_apbi0   => mem_apbi0, 
    --  mem_apbo0   => mem_apbo0, 
    -- PROM controller
  --  rom_ahbsi1  => rom_ahbsi1,
  --  rom_ahbso1  => rom_ahbso1,
--    -- Ethernet PHY
--    ethi        => ethi,
--    etho        => etho,
--    eth_apbi    => eth_apbi,
--    eth_apbo    => eth_apbo,
    -- Debug UART
    duart_rx    => lduart_rx,
--    duart_tx    => lduart_tx,
    -- Debug JTAG
    tck         => tck,
    tms         => tms,
    tdi         => tdi,
    tdo         => tdo
  );

  dmen_pad : inpad
    generic map (tech => padtech)
    port map (dmen, ldmen);

  dmbreak_pad : inpad
    generic map (tech => padtech)
    port map (dmbreak, ldmbreak);

--  dmreset_pad : outpad
--    generic map (tech => padtech)
--    port map (dmreset, ldmreset);

  errorn_pad : odpad
    generic map (tech => padtech, oepol => OEPOL)
    port map (cpu0errn, lcpu0errn);

  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------

  uart_rx_pad : inpad
    generic map (tech => padtech)
    port map (uart_rx, luart_rx(0));
  uart_tx_pad : outpad
    generic map (tech => padtech)
    port map (uart_tx, luart_tx(0));
  uart_ctsn_pad : inpad
    generic map (tech => padtech)
    port map (uart_ctsn, luart_ctsn(0));
  uart_rtsn_pad : outpad
    generic map (tech => padtech)
    port map (uart_rtsn, luart_rtsn(0));

  duart_rx_pad : inpad
    generic map (tech => padtech)
    port map (duart_rx, lduart_rx);
--  duart_tx_pad : outpad
--    generic map (tech => padtech)
--    port map (duart_tx, lduart_tx);

  -----------------------------------------------------------------------------
  -- Memory Controller --------------------------------------------------------
  -----------------------------------------------------------------------------
  -- No APB interface on memory controller  
  -- mem_apbo0    <= apb_none;









-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map(
      msg1    => "NOELV/GRLIB Generic Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on

end rtl;


