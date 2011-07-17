module Gtk2GO
  class Value
    attr_accessor :value
  end

  class Border
    def _liberties(player,store)
      return 0
    end
    def _territories(count,store)
      count[nil] &&= false
      return count
    end
    def occupied?
      true
    end
    def player
      nil
    end
  end

  BORDER = Border.new

  class Cell
    attr_accessor	:up,:down,:left,:right,
			:player, :occupied,
			:counted, :store

    def initialize(index=nil)
      @index = index

      @up	=
      @down	=
      @left	=
      @right	= BORDER	# four edges
      @player	= nil		# initially neutral
      @store	= nil		# initially un-calculated
      @occupied	= false		# initially un-occupied
      @counted	= false		# recursion flag
    end

    def occupied?
      @occupied
    end

    def occupyable?(player)
      return :no if @occupied
      enemy_eye = true
      self.edges.each do |edge|
        return :yes if !edge.occupied?
        eye = false if edge.player == player
      end
      return :no if enemy_eye
      return :maybe
    end

    def vacate!
      @occupied = false
      @player = nil
    end

    def occupy!(player)
      @occupied = true
      @player = player
    end

    def connect_up(node)
      @up = node
      node.down = self
    end
    # connect_down(node) not necessary

    def connect_left(node)
      @left = node
      node.right = self
    end
    # connect_right(node) not necessary

    def reset_counted
      @counted = false
    end

    def reset_store
      @store = nil
    end

    def edges
      [@up, @down, @left, @right]
    end

    def _liberties(player,store)
      return 0	if @counted		# no double counting
      @counted = true
      return 1	if !@occupied		# cell is a source of liberty
      return 0	if !(@player == player)	# cell is an oponent

      # cell is a connection to possible liberties.
      @store = store
      count = 0
      self.edges.each{|edge| count += edge._liberties(player,store) }
      return count
    end

    def liberties
      return @store.value	if @store # store is a pointer to value
      self.store = store = Value.new
      store.value = self._liberties(@player,store)
    end

    def _territories(count,store)
      if !@counted? then # no double counting
        @counted = true
        if @occupied? then # connected to player
          count[@player] += 1
        else # cell is a connection to possible players
          @store = store
          self.edges.each{|edge| edge._territories(count,store)}
        end
      end
      return count
    end

    def territories
      return @store.value	if @store # store is a pointer to value
      count=Hash.new(0)
      @store = Value.new
      @store.value = self._territories(count,@store)
    end
  end # of Cell

end
