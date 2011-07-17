require 'gtk2go/cell'

module Gtk2GO
  class Board
    EMPTY = '.'

    def initialize(board_size=[9,9],number_of_players=2)
      @rows, @columns	= board_size
      @number_of_players = number_of_players
      @cells = []

      index = 0; cell = nil
      @rows.times do
        @columns.times do
          @cells.push( cell = Cell.new(index) )
          cell.connect_up(@cells[index-@columns])	if index >= @columns
          cell.connect_left(@cells[index-1])		if index % @columns > 0
          index += 1
        end
      end
    end

    def [](x,y)
      return @cells[ x*@columns + y ]
    end

    def state
      string = ''
      @cells.each do |cell|
        string += (cell.player)? cell.player.to_s: EMPTY
      end
      return string
    end

    def set_state(string)
      index = 0
      string.each_char do |char|
        cell = @cells[index]
        if char == EMPTY then
          cell.vacate!
        else
          cell.occupy!(char.to_i)
        end
      end
    end

    def reset_store
      @cells.each{|cell| cell.reset_store}
    end

    def reset_counted
      @cells.each{|cell| cell.reset_counted}
    end

    def reset
      self.reset_store
      self.reset_counted
    end

    def captured
      captured = []
      self.reset_store
      @cells.each do |cell|
        if cell.occupied? then
          self.reset_counted
          captured.push([cell,cell.player]) if cell.liberties < 1
        end
      end
      return captured
    end

    def finalyze
      captured = self.captured
      captured.each {|cell,player| cell.vacate!}
      return captured
    end

    def restore(captured)
      captured.each {|cell,player| cell.occupy!(player)}
    end

    def occupyable?(position,player)
      occupyable = true # assumed
      case position.occupyable?(player)
        when :no
          occupyable = false
        when :maybe
          position.occupy!(player)
          captured = self.finalyze
          self.reset
          occupyable = false if position.liberties < 1
          position.vacate!
          self.restore(captured)
      end
      return occupyable
    end

    # Note: there's no checking for occupyable.
    def occupy!(position,player)
      position.occupy!(player)
      self.finalyze
    end

    # Note: board must be in a finalyzed state
    def evaluate_liberties
      occupied	= Hash.new(0)
      liberties	= Hash.new(0)
      self.reset_store
      @cells.each do |cell|
        if cell.occupied? then
          player = cell.player
          occupied[player] += 1
          self.reset_counted
          liberties[player] += cell.liberties # TBD: need reset_*? Want finalyze to preset the values?
        end
      end
      return liberties, occupied
    end

    def evaluate_territories
      fenced	= Hash.new(0)
      conquered	= Hash.new(0)
      influenced= Hash.new(0)

      is_fenced = nil # set here for speed
      self.reset_store
      @cells.each do |cell|
        if !cell.occupied? then
          self.reset_counted
          count = cell.territory
          is_fenced = count.delete(nil)
          count = count.sort{|a,b| b[1]<=>a[1]}
          player,winner = count.shift
          looser = count.shift[1]
          if winner - looser > 1 then
            if looser == 0 then
              (is_fenced)? (fenced[color] += 1): (conquered[color] += 1)
            else
              influenced[color] += 1
            end
          end
        end
      end
      return fenced, conquered, influenced
    end

    def scores
      liberties, occupied, vacated = self.evaluate_liberties
      fenced, conquered, influenced = self.evaluate_territories
      scores = []
      @number_of_players.times do |player|
        scores.push( Gtk2GO.heuristic(fenced[player], conquered[player], influenced[player], occupied[player], liberties[player]) )
      end
      return scores
    end

    def evaluation(player)
      scores = self.scores
      player_score = scores.delete_at(player)
      opponent_score = scores.sort.pop
      return player_score - opponent_score
    end

    def evaluate_position(position,player)
      valuation = nil
      if self.occupyable?(position) then
        current = self.evaluation(player)
        self.occupy!(position,player)
        later = self.evaluation(player)
        valuation = later - current
      end
      return valuation
    end
  end
end
