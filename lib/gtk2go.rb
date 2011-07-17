module Gtk2GO

  TERRITORIES = {
	PLAYER1	=> {
		:influenced	=> INFLUENCED1,
		:conquered	=> CONQUERED1,
		:fenced		=> FENCED1,
	},
	PLAYER2	=> {
		:influenced	=> INFLUENCED2,
		:conquered	=> CONQUERED2,
		:fenced		=> FENCED2,
	},
  }

  TOKEN	= {
	PLAYER1	=> TOKEN1,
	PLAYER2	=> TOKEN2,
  }

  PLAYER = [PLAYER1,PLAYER2]

  # just want to add a method
  class Button < Gtk2AppLib::Widgets::Button
    def background(color)
      color = CLEAR if color.nil?
      self.modify_bg(Gtk::STATE_NORMAL,color)
      self.modify_bg(Gtk::STATE_PRELIGHT,color)
    end
  end

  class Border
    def initialize
      # nothing honey
    end
    def _liberties(color,store)
      return 0
    end
    def _territory(count,store)
      count[nil] += 1	# borders don't have color
      return count
    end
    def modify_bg(*parameters)
      # nothing
    end
  end

  class Value
    attr_accessor :value
  end

  module Cell
    BORDER = Border.new

    attr_accessor	:up,:down,:left,:right,
			:color, :occupied,
			:counted, :store

    def init
      self.up		=
      self.down		=
      self.left		=
      self.right	= BORDER	# four edges
      self.color	= nil		# initially neutral
      self.store	= nil		# initially un-calculated
      self.occupied	= false		# initially un-occupied
      self.counted	= false		# recursion flag
    end

    def occupied?
      self.occupied
    end

    def counted?
      self.counted
    end

    def vacate!
      self.color = nil
      self.occupied = false
    end

    def occupy!(color)
      self.color = color
      self.occupied = true
    end

    def connect_up(node)
      self.up = node
      node.down = self
    end

    def connect_down(node)
      self.down = node
      node.up = self
    end

    def connect_left(node)
      self.left = node
      node.right = self
    end

    def connect_right(node)
      self.right = node
      node.left = self
    end

    def reset_counted
      self.counted = false
    end

    def reset_store
      self.store = nil
    end

    def edges
      [self.up, self.down, self.left, self.right]
    end

    def _liberties(color,store)
      return 0	if self.counted?		# no double counting
      self.counted = true
      return 1	if !self.occupied?		# cell is a source of liberty
      return 0	if !(self.color == color)	# cell is an oponent

      # cell is a connection to possible liberties.
      self.store = store
      count = 0
      self.edges.each{|edge| count += edge._liberties(color,store) }
      return count
    end

    def liberties(color=self.color)
      if store = self.store then
        return store.value
      end
      self.store = store = Value.new
      store.value = self._liberties(color,store)
    end

    def _territory(count,store)
      if !self.counted? then # no double counting
        self.counted = true
        if self.occupied? then # cell is a source of color
          count[self.color] += 1
        else # cell is a connection to possible colors
          self.store = store
          self.edges.each{|edge| edge._territory(count,store)}
        end
      end
      return count
    end

    def territory(count=Hash.new(0))
      if store = self.store then
        return store.value
      end
      self.store = store = Value.new
      store.value = self._territory(count,store)
    end

  end

  class ButtonCell < Button
    include Cell # mixin

    def initialize(*parameters)
      super(*parameters)
      self.init
    end

    def vacate!
      super
      background(nil)
    end

    def color=(color)
      super
      background(color)
    end

    def occupy!(color)
      super
      background(color)
    end

  end

  class Board

    def reset_counted
      @cells.each{|cell| cell.reset_counted}
    end
    def reset_store
      @cells.each{|cell| cell.reset_store}
    end

    def finalyze
      deads = []
      liberties = nil
      yielding = block_given?
      self.reset_store
      @cells.each do |cell|
        if cell.occupied? then
          self.reset_counted
          liberties = cell.liberties
          if liberties < 1 then
            yielding = false	if yielding
            deads.push([cell,cell.color]) # this allows it to be reversible
          end
          yield(cell,liberties)	if yielding
        end
      end
      return deads
    end

    def evaluate_liberties
      occupied = liberties = vacated = nil
      not_finalyzed = true
      while not_finalyzed do
        liberties = Hash.new(0)
        occupied = Hash.new(0)
        deads = self.finalyze do |cell,liberty|
          color = cell.color
          liberties[color] += liberty
          occupied[color] += 1
          yield(cell,liberty,color) if block_given?
        end
        if deads.length > 0 then
          raise "ERROR: Only expected to need to vacate once." if vacated
          deads.each{|cell| cell.first.vacate!}
          vacated = deads
        else
          not_finalyzed = false
        end
      end
      return liberties, occupied, vacated
    end

    def evaluate_territories
      fenced = Hash.new(0)
      conquered = Hash.new(0)
      influenced = Hash.new(0)
      self.reset_store
      @cells.each do |cell|
        if !cell.occupied? then
          self.reset_counted
          count = cell.territory
          is_fenced = (count[nil] == 0)
          count.delete(nil)
          count = count.sort{|a,b| a[1]<=>b[1]}
          color,winner = count.pop || [nil,0] # winner
          looser = (count[0])? count.shift[1]: 0
          if winner - looser > 1 then
            if looser == 0 then
              if is_fenced then
                fenced[color] += 1
                yield(cell,color,:fenced)	if block_given?
              else
                conquered[color] += 1
                yield(cell,color,:conquered)	if block_given?
              end
            else
              influenced[color] += 1
              yield(cell,color,:influenced)	if block_given?
            end
          elsif block_given?
            yield(cell,nil,:none)
          end
        end
      end
      return fenced, conquered, influenced
    end

    def self.score_label(p, fenced, conquered, influenced, occupied, liberties)
      p = [fenced[p], conquered[p], influenced[p], occupied[p], liberties[p]]
      score = Gtk2GO.score(*p)
      #return "#{score}\t(" + p.join(",") + ')'
      return score.to_s
    end

    def evaluate(button=nil)
      player = PLAYER[@turn%2]
      opponent = PLAYER[(@turn+1)%2]
      button.occupy!(player) if button

      liberties, occupied, vacated = self.evaluate_liberties
      fenced, conquered, influenced = self.evaluate_territories
      score1 = Gtk2GO.heuristic(fenced[player], conquered[player], influenced[player], occupied[player], liberties[player])
      score2 = Gtk2GO.heuristic(fenced[opponent], conquered[opponent], influenced[opponent], occupied[opponent], liberties[opponent])
      difference = score1 - score2

      # restore
      vacated.each{|cell| cell.first.occupy!(cell.last)}	if vacated
      button.vacate! if button

      return difference
    end

    def settle
      liberties, occupied, vacated =
      self.evaluate_liberties{|cell,liberty,color| cell.label = (liberty>1)? TOKEN[color]: TOKEN[color] + '!'}
      vacated.each{|cell| cell.first.label = ''}	if vacated
      fenced, conquered, influenced =
      self.evaluate_territories{|cell,color,type| (type == :none)? (cell.color = nil): (cell.color = TERRITORIES[color][type])}
      @score1.text = Board.score_label(PLAYER1, fenced, conquered, influenced, occupied, liberties)
      @score2.text = Board.score_label(PLAYER2, fenced, conquered, influenced, occupied, liberties)
    end

    def next
      @turn += 1
      player = @turn%2
      @computer.label = COMPUTER[player]
      @computer.background(PLAYER[player])
      if (player==0)? @autoplay1.active?: @autoplay2.active? then
        Gtk.timeout_add(100) do
          @computer.activate
        end
      end
    end

    def pass
      if @passed then
        self.end_game
      else
        self.next
        @passed = true
      end
    end

    def play(cell,active=true)
      played = false
      cell.occupy!( PLAYER[@turn%2] )
      self.reset_store
      self.reset_counted
      if cell.liberties > 0 then
        self.settle
        self.next
        played = true
        @passed = false
      else
        cell.vacate!
        if active then
          cell.label = '0!'
          Gtk.timeout_add(1000) do
            cell.label = ''
            false
          end
        end
      end
      return played
    end

    def end_game
      @computer.label = 'End Game'
      @computer.background(nil)
    end

    def rank_positions(vacant)
      vacant.shuffle!
      # searching for best move
      heuristics = {}
      vacant.each{|cell| heuristics[cell] = rand}
      count = 0
      diff0 = self.evaluate
      start = Time.now
      time = nil
      vacant.each do |cell|
        diff1 = self.evaluate(cell)
        heuristics[cell] = diff1 - diff0
        count += 1
        time = Time.now - start
        break if time > TIMEOUT
      end
      $stderr.puts "Evaluated #{count} cells in #{time}"	if $trace
      vacant.delete_if{|a| heuristics[a] < 0 }	# delete bad moves
      vacant.sort!{|a,b| heuristics[b] <=> heuristics[a]}
    end

    def cell_search(vacant)
      rank_positions(vacant)
      while cell = vacant.shift do
        return	if play(cell,false)	# succesful move found
      end
      self.pass # no move found, pass.
    end

    def computer_player
      vacant = @cells.select{|cell| !cell.occupied? }
      length = vacant.length
      (length > 0)? cell_search(vacant): self.pass
    end

    def restart
      @cells.each do |cell|
        cell.vacate!
        cell.label = ''
        @score1.text = '0'
        @score2.text = '0'
        @turn = 0
        @computer.label = COMPUTER.first
        @computer.background(PLAYER1)
        if @autoplay1.active? then
          Gtk.timeout_add(100) do
            @computer.activate
          end
        end
      end
    end

    def initialize(rows,columns,container)
      @turn = 0
      @passed = false

      index = 0
      @cells = []
      vbox = Gtk2AppLib::Widgets::VBox.new(container)
      rows.times do
        hbox = Gtk2AppLib::Widgets::HBox.new(vbox)
        columns.times do
						# Ruby 1.8 can't handle method( *array, parameter )
          cell = ButtonCell.new( *CELL_PARAMETERS + [hbox]){|is,signal,button,*emits| self.play(button) if !button.occupied?}
          @cells.push(cell)
          cell.connect_up(@cells[index-columns])	if index >= columns
          cell.connect_left(@cells[index-1])		if index%columns > 0
          index += 1
        end
      end

						# Ruby 1.8 can't handle method( *array, parameter )
      @computer		= Button.new(				*AUTOPLAY	+	[vbox.children[0]]){ self.computer_player }
      @pass		= Button.new(				*PASS		+	[vbox.children[0]]){ self.pass }
      			  Gtk2AppLib::Widgets::Label.new(	*LABEL1		+	[vbox.children[1]])
      @score1		= Gtk2AppLib::Widgets::Label.new(	*SCORE12	+	[vbox.children[1]])
      			  Gtk2AppLib::Widgets::Label.new(	*LABEL2		+	[vbox.children[2]])
      @score2		= Gtk2AppLib::Widgets::Label.new(	*SCORE12	+	[vbox.children[2]])
      @autoplay1	= Gtk2AppLib::Widgets::CheckButton.new(	*AUTOPLAY1	+	[vbox.children[3]])
      @autoplay2	= Gtk2AppLib::Widgets::CheckButton.new(	*AUTOPLAY2	+	[vbox.children[3]])
      @restart		= Button.new(				*RESTART	+	[vbox.children[8]]){ self.restart }
      @quit		= Button.new(				*QUIT		+	[vbox.children[8]]){ Gtk.main_quit }

      @computer.background(PLAYER1)
    end
  end
end
