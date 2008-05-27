require 'net/http'
require 'rexml/document'

class SLStatsPlugin < Plugin
  RESPONSE_TEXT = { 'inworld' => 'Residents online',
    'transactions' => 'Daily transactions',
    'population' => 'Total population'
  }

  def initialize
    @slstats = {}
    @last_stats_pull = Time.now - 30
    super
  end

  def help(plugin, topic="")
    return "slstats [item] => Get the current Second Life statistics. \
'item' is either 'population', 'transactions', 'inworld'.  All will be \
shown if parameter is missing."
  end

  def stats(m, params)
    stat_item = params[:key]
    stat_item = 'all' unless stat_item
    unless RESPONSE_TEXT.has_key?(stat_item) || stat_item == 'all'
      m.reply("#{stat_item} is not a valid type.  Try 'help slstats'")
      return
    end

    time_diff = Time.now - @last_stats_pull
    get_stats unless time_diff < 30

    # Format results
    if stat_item == 'all'
      response_text = format_stats(@slstats)
    else
      response_text = format_stats({stat_item => @slstats[stat_item]})
    end

    m.reply(response_text)
  end

  def format_stats(stats)
    response = ""
    stats.each do |key, value|
      label = RESPONSE_TEXT[key]
      response += "#{label}: #{value} "
    end
    return response
  end
    
  def get_stats
    Net::HTTP.start('secondlife.com', 80) { |http|
      response = http.get('/xmlhttp/secondlife.php')
      xml = REXML::Document.new(response.body,
                                { :ignore_whitespace_nodes => :all } )
      xml.root.each_child { |child| 
        @slstats[child.name] = child.text
      }
    }
    @last_stats_pull = Time.now
  end
end

plugin = SLStatsPlugin.new
plugin.map "slstats :key", {:action => :stats, :defaults => {:key => false}}
