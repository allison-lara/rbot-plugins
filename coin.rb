class CoinPlugin < Plugin
  def help(plugin, topic="")
    return "coin => flip a coin, coin stats => show your coin flipping stats"
  end
  
  def initialize
    @coin = ["heads", "tails"]
    super
  end
  
  def flip_coin(m, params)
    num = params[:number].to_i
    
    m.reply "I can only flip positive numbers of coins." unless num > 0
    m.reply "Sorry, I've only got 20 coins in my pocket." unless num <= 20
    return unless num > 0 && num <= 20
    
    playerdata = get_data(m.sourcenick) || Array.new(2,0)
    result = []
    1.upto(num) do |i|
      flip = rand(2)
      playerdata[flip] += 1
      result << @coin[flip]
    end
    m.reply result.join(", ")
    @registry[m.sourcenick] = playerdata
  end

  def coin_stats(m, params)
    playerdata = get_data(m.sourcenick)
    unless playerdata.nil?
      total = playerdata.inject {|sum, i| sum + i}
      heads, tails = playerdata
      hp, tp = playerdata.map {|i| sprintf("%.2f", (i.to_f / total) * 100)}
      m.reply "#{heads} heads (#{hp}%) and #{tails} tails (#{tp}%)"
    else
      m.reply "Sorry, you haven't flipped any coins."
    end    
  end

  private
  def get_data(name)
    @registry[name] if @registry.has_key?(name)
  end
end

plugin = CoinPlugin.new
plugin.map 'coin stats', :action => 'coin_stats'
plugin.map 'coin :number', {:action => 'flip_coin', :defaults => {:number => 1}}
