module Gtk2GO
  TIMEOUT = 15.0 # seconds computer is allowed "think"

  color = ($options=~/c/)? true: false

  PLAYER1 = Gdk::Color.parse('#A0CFEC')
  PLAYER2 = Gdk::Color.parse('#F75D59')

  INFLUENCED1	= (color)? Gdk::Color.parse('#A0CFEC'): nil
  INFLUENCED2	= (color)? Gdk::Color.parse('#F75D59'): nil

  CONQUERED1	= (color)? Gdk::Color.parse('#82CAFA'): nil
  CONQUERED2	= (color)? Gdk::Color.parse('#E55451'): nil

  FENCED1	= (color)? Gdk::Color.parse('#87AFC7'): nil
  FENCED2	= (color)? Gdk::Color.parse('#C24641'): nil

  CLEAR	= (Gtk2AppLib::Configuration::X)? nil: Gtk2AppLib::Color[/White/]

  TOKEN1	= 'X'
  TOKEN2	= 'O'

  COMPUTER = ["#{TOKEN1} Plays","#{TOKEN2} Plays"]

  clicked	= 'clicked'
  button_width	= {:width_request= => 150}.freeze
  large_font	= {:modify_font => Gtk2AppLib::Configuration::FONT[:LARGE]}.freeze
  small_font	= {:modify_font => Gtk2AppLib::Configuration::FONT[:SMALL]}.freeze
  cell_options	= {:width_request= => 46, :height_request= => 46, :modify_font => Gtk2AppLib::Configuration::FONT[:LARGE]}.freeze

  CELL_PARAMETERS = ['',		cell_options, clicked].freeze
  AUTOPLAY1	= ["#{TOKEN1} Autoplays",	small_font].freeze
  AUTOPLAY2	= ["#{TOKEN2} Autoplays",	small_font].freeze
  QUIT		= ['Quit',		large_font, button_width, clicked].freeze
  RESTART	= ['Restart',		large_font, button_width, clicked].freeze
  PASS		= ['Pass',		large_font, button_width, clicked].freeze
  LABEL1	= [" #{TOKEN1}:\t",		large_font].freeze
  LABEL2	= [" #{TOKEN2}:\t",		large_font].freeze
  SCORE12	= ['0',			large_font].freeze
  AUTOPLAY	= [COMPUTER.first,	large_font, button_width, clicked].freeze

  # Here you can define the scoring.
  def self.score( fenced, conquered, influenced, occupied, liberties )
    fenced + conquered + occupied
  end
  # Here you can define AI's heuristics
  def self.heuristic( fenced, conquered, influenced, occupied, liberties )
    score = 16*fenced + 8*conquered + 4*occupied + 2*influenced + liberties + rand
    return score
  end
end

module Gtk2AppLib
module Configuration
  MENU[:dock] = '_Dock'		if !HILDON
  MENU[:fs] = '_Fullscreen'	if HILDON
end
end
