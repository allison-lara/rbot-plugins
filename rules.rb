class RulesPlugin < Plugin
  def name
    return "rules"
  end

  def initialize
    super
    @rules = Hash.new
    Dir["#{@bot.botclass}/rules/*"].each do |f|
      next if File.directory?(f)
      channel = File.basename(f)
      warning "loading rules from #{@bot.botclass}/rules/#{channel}"
      @rules[channel] ||= Array.new
      IO.foreach(f) do |line|
        @rules[channel] << line
      end
    end
  end

  def save_rules(channel)
    Dir.mkdir("#{@bot.botclass}/rules") unless FileTest.directory?("#{@bot.botclass}/rules")
    File.open("#{@bot.botclass}/rules/#{channel}", "w") do |file|
      @rules[channel].compact.each do |rule| 
        file.puts "#{rule}"
      end
    end
  end

  def rule(channel, i)
    rules = @rules[channel]
    return unless rules
    if i >= 1 && i <= rules.length
      rules[i - 1]
    else
      nil
    end
  end

  def rule_handler(m, params)
    channel = m.target.name
    idx = params[:number]
    m.reply "No rules for #{channel}" unless @rules[channel]
    if idx
      i = idx.to_i
      rule_text = rule(channel,i)
      if rule_text
        m.reply "#{i}) #{rule_text}"
      end
    else
      m.reply "Must provide a rule number.  There are #{@rules[channel].length} rules."
    end
  end
end

plugin = RulesPlugin.new
plugin.map "rule :number", {:action => :rule_handler, :defaults => {:number => nil}}
