require 'open-uri'
require 'cgi'

class ConvertPlugin < Plugin
  def help(plugin, topic="")
    return "convert <expression> => Try to convert <expression> using Google's calculator"
  end
  
  def privmsg(m)
    m.reply "Incorrect usage. " + help(m.plugin) unless m.params
    result = convert(m.params)
    if result
      m.reply "Result: #{result}"
    else
      m.reply "No result found."
    end
  end
  
  def convert(expression)
    result = nil
    args = expression << "="
    args = CGI.escape(args)
    open("http://www.google.com/search?q=#{args}") do |html|
      text = html.read
      counter = 0
      text.scan(/calc_img.+?<b>(.+?)<\/b>/) do |result|
        stripped_result = result[0]
        stripped_result = stripped_result.gsub( /<sup>(.+?)<\/sup>/, "^(\\1)" )
        stripped_result = stripped_result.gsub( /<font size=-2> <\/font>/, "" )
        stripped_result = stripped_result.gsub( /<[^>]+>/, "" )
        stripped_result = stripped_result.gsub( /&times;/, "x" )
	stripped_result = stripped_result.gsub( /&#215;/, "x" )
        result = stripped_result
        counter += 1
        break
      end
    end
    return result
  end
end

plugin = ConvertPlugin.new
plugin.register("convert")
