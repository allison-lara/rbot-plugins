require 'hpricot'
require 'open-uri'
require 'cgi'

module Armory
  MOZ_AGENT = "Mozilla/5.0 Gecko/20070219 Firefox/2.0.0.2"

  ARMORY_URL = "http://www.wowarmory.com"

  TALENTS = {
    "Warlock" => ["Affliction", "Demonology", "Destruction"],
    "Warrior" => ["Arms", "Fury", "Protection"],
    "Priest" => ["Discipline", "Holy", "Shadow"],
    "Paladin" => ["Holy", "Protection", "Retribution"],
    "Druid" => ["Balance", "Feral", "Restoration"],
    "Rogue" => ["Assassination", "Combat", "Subtlety"],
    "Hunter" => ["Beast Mastery", "Marksmanship", "Survival"],
    "Shaman" => ["Elemental", "Enhancement", "Restoration"],
    "Mage" => ["Arcane", "Fire", "Frost"]
  }

  HEROIC_FACTION_KEYS = %w(cenarionexpedition thrallmar honorhold lowercity thesha'tar keepersoftime)

  HEROIC_FACTION_HUBS = {
    "cenarionexpedition" => "Coilfang Reservoir",
    "thrallmar" => "Hellfire Citadel",
    "honorhold" => "Hellfire Citadel",
    "lowercity" => "Auchindoun",
    "thesha'tar" => "Tempest Keep",
    "keepersoftime" => "Caverns of Time"
  }

  FACTION_POINTS_TO_LEVEL = {
    "Hated" => 36000,
    "Hostile" => 3000,
    "Unfriendly" => 3000,
    "Neutral" => 3000,
    "Friendly" => 6000,
    "Honored" => 12000,
    "Revered" => 21000,
    "Exalted" => 999
  }
  
  class MemFetcher
    def initialize
      @cache = {}
    end
    
    def fetch(uri, max_age=3600)
      if @cache.has_key? uri
        return @cache[uri][1] if Time.now-@cache[uri][0] < max_age
      end

      @cache[uri] = [Time.now, open(uri, "User-Agent" => MOZ_AGENT).read]
      return @cache[uri][1]
    end
  end
  
  # Expects an instance variable called @doc
  module ArmoryUtil
    def armory_uri(xml, name, realm)
      r = CGI.escape(realm)
      n = CGI.escape(name)
      "#{ARMORY_URL}/#{xml}.xml?r=#{r}&n=#{n}"
    end
  
    def fetch_armory_xml(uri, max_age=3600)
      @@fetcher ||= MemFetcher.new
      doc = @@fetcher.fetch(uri, max_age)
      Hpricot.XML(doc)
    end
  
    def xml_attr_value(xpath, attrib)
      @doc.at(xpath)[attrib]
    end
    module ClassMethods
      def xml_attr_reader(name, xpath, attr)
        define_method name do
          xml_attr_value xpath, attr
        end
      end
    end
    
    def self.included(reciever)
      reciever.extend(ClassMethods)
    end
  end

  class Character
    include ArmoryUtil

    attr_accessor :xml
    attr_reader :professions
    attr_reader :talents
    
    def initialize(name, realm)
      @doc = fetch_armory_xml(armory_uri('character-sheet', name, realm),300)

      unless @doc.at('character')
        raise "#{name} does not exist on #{realm}" 
      end
      @needs_refresh = @doc.at('//characterTab').nil?
      @professions = gen_professions
      @talents = nil
      @reputations = nil
    end
  
    xml_attr_reader :name, "//character", "name"
    xml_attr_reader :guild_name, "//character", "guildName"
    xml_attr_reader :wow_class, "//character", "class"
    xml_attr_reader :level, "//character", "level"
    xml_attr_reader :race, "//character", "race"
    xml_attr_reader :realm, "//character", "realm"
  
    def needs_refresh?
      @needs_refresh
    end
    
    def talents
      unless @talents
        @talents = []
        telm = @doc.at('talentSpec')
        unless telm
          tvals = [0,0,0]
        else
          tvals = [telm['treeOne'], telm['treeTwo'], telm['treeThree']]
        end
        tvals.each_with_index do |obj, i|
          @talents[i] = [i+1, obj.to_i, TALENTS[self.wow_class][i]]
        end
      end
      @talents
    end
    
    def reputations
      unless @reputations
        @reputations = Reputation.new(name, realm)
      end
      @reputations
    end
  
    def talent_spec
      sorted_talents = talents.sort {|a,b| b[1] <=> a[1] }
  
      diff_middle_lowest= sorted_talents[1][1] - sorted_talents[2][1] 
      diff_highest_lowest = sorted_talents[0][1] - sorted_talents[2][1]
  
      return "Untalented" if sorted_talents[0][1] == 0
      return "Hybrid" if 3 * diff_middle_lowest >= 2 * diff_highest_lowest
      return sorted_talents[0][2]
    end
  
    private
    def gen_professions
      profs = {}
      (@doc/:professions/:skill).each do |skill|
        profs[skill["key"]] = {
          :name => skill["name"],
          :value => skill["value"],
          :max => skill["max"]
        }
      end
      return profs
    end
  end

  class Reputation < DelegateClass(Hash)
    include ArmoryUtil

    def initialize(name, realm)  
      @doc = fetch_armory_xml(armory_uri('character-reputation', name, realm))
      @reputation = build_rep
      super(@reputation)
    end

    def kara_keyed?
      return false if @reputation["thevioleteye"].nil?
      @reputation["thevioleteye"][:value] > 2100
    end
    
    private
    def build_rep
      hash = {}
      (@doc/:faction).each do |faction|
        value = faction["reputation"].to_i
        level, current, remaining = calculate(value)
        hash[faction["key"]] = {
          :name => faction["name"],
          :value => value,
          :level => level,
          :current => current,
          :remaining => remaining 
        } 
      end
      hash
    end
    
    def calculate(value)
      case value
      when -6000..-3001
        ["Hostile", (value + 3000).abs, (value + 3000).abs]
      when -3000..-1
        ["Unfriendly", (value - 0).abs, (value - 0).abs]
      when 0..2999
        ["Neutral", value - 0, 3000 - value]
      when 3000..8999
        ["Friendly", value - 3000, 9000 - value]
      when 9000..20999
        ["Honored", value - 9000, 21000 - value]
      when 21000..41999
        ["Revered", value - 21000, 42000 - value]
      when 42000..42999
        ["Exalted", value - 42000, 42999 - value]
      else
        ["Hated", (value + 6000).abs, (value + 6000).abs]
      end
    end
  end
end

class ArmoryPlugin < Plugin
  REALM_KEY='armory.server.default'
  
  BotConfig.register BotConfigStringValue.new(REALM_KEY,
    :default => "Kul Tiras", 
    :desc => "Default World of Warcraft server when not specified") 

  def initialize
    @cache = Hash.new do |h,k|
      h[k] = {:data => nil, :when => Time.new(0) }
    end
    super
  end

  def help(plugin, topic="")
    case topic
    when "keys"
      "armory keys <name> [realm] => Find out which heroic keys a character has."
    when "show"
      "armory <name> [realm] => Print some character information from the WoW Armory."
    when "faction"
      "armory faction <faction> <name> [realm] => Show reputation data for a faction."
    else
      "Look up information in the WoW Armory. Topics: show, keys, faction"
    end
  end

  def get_character_data(name, realm, m)
    begin
      Armory::Character.new(name, realm)
    rescue Timeout::Error
      m.reply "Connection timed out, try again later."
    rescue Exception => e
      m.reply "Unable to load data: #{e}"
    end
  end

  def lookup(m, params)
    name, realm = parse_params params
  	
    c = get_character_data(name, realm, m)
    
    return if c.nil?

    guildstr = "<#{c.guild_name}> " if c.guild_name.length > 0
    profstr = c.professions.collect{|k,v| "#{v[:name]}: #{v[:value]}/#{v[:max]}" }.join(" ")
    talent_spec_str = "#{c.talent_spec} " unless c.needs_refresh?
    talent_data = "(" + c.talents.collect{|v| v[1]}.join("/") + ")" unless c.needs_refresh?

    m.reply "#{c.name} #{guildstr}of #{c.realm} - Level #{c.level} #{c.race} #{talent_spec_str}#{c.wow_class} #{talent_data}"
    return if c.level.to_i < 10
    if profstr.length > 0 
      m.reply "#{c.name}'s professions are #{profstr}"
    end
    if c.needs_refresh?
      m.reply "#{c.name} hasn't been active for some time and is missing detailed information."
    end
  end
  
  def heroic_keys(m, params)
    name, realm = parse_params params
    
    c = get_character_data(name, realm, m)
    
    return if c.nil?
    
    heroic_keys = c.reputations.select do |k,v|
      Armory::HEROIC_FACTION_KEYS.include? k and v[:value] >= 12000
    end

    instance_names = heroic_keys.map{ |o| Armory::HEROIC_FACTION_HUBS[o[0]] }
    instance_names << "Karazhan" if c.reputations.kara_keyed?
    instance_names.sort!
    
    keys_str = case instance_names.length
      when 0
        "None"
      when 1
        instance_names.flatten
      when 2
        instance_names.join(" and ")
      else
        instance_names[0..-2].join(", ") + " and " + instance_names[-1]
      end
    
    m.reply("#{c.name} is keyed for: #{keys_str}")
  end
  
  def faction(m, params)
    name, realm = parse_params params
    faction_key = params[:faction].downcase
    
    c = get_character_data(name, realm, m)
    
    return if c.nil?
    
    faction_data = c.reputations[faction_key]
    unless faction_data
      faction_pattern = faction_key.gsub(/[^a-z0-9']/,'')
      matches = c.reputations.keys.map{|o| o.to_s}.grep(/#{faction_pattern}/)
      faction_data = c.reputations[matches[0]] unless matches.size == 0
    end
    
    if faction_data
      level = faction_data[:level]
      threshold = Armory::FACTION_POINTS_TO_LEVEL[level]
      current = faction_data[:current]
      to_go = ""
      unless level == "Exalted"
        to_go = " and needs #{faction_data[:remaining]} points for the next level"
      end
      m.reply "#{c.name} of #{c.realm} is #{level} (#{current}/#{threshold}) with #{faction_data[:name]}#{to_go}"
    else
      m.reply "#{faction_key} is an unknown faction for #{name} of #{realm}"
    end
  end
  
  private
  def parse_params(params)
    name = params[:name]
    realm = @bot.config[REALM_KEY] if params[:realm].empty?
    realm ||= params[:realm].join(" ")
    [name, realm]
  end
end

plugin = ArmoryPlugin.new
plugin.map "armory faction :faction :name *realm", {:action => :faction, :defaults => {:realm => []}}
plugin.map "armory keys :name *realm", {:action => :heroic_keys, :defaults => {:realm => []}}
plugin.map "armory :name *realm", {:action => :lookup, :defaults => {:realm => []}}
