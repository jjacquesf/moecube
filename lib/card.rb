#encoding: UTF-8
#==============================================================================
# ■ Scene_Login
#------------------------------------------------------------------------------
# 　login
#==============================================================================
class Card
	require 'sqlite3'
	@db = SQLite3::Database.new( "data/data.sqlite" )
	@all = []
	@count = @db.get_first_value("select COUNT(*) from YGODATA") rescue 0
	@db.results_as_hash = true
	PicPath = 'E:/game/yu-gi-oh/YGODATA/YGOPIC'

	class << self
		def find(id, order_by=nil)
      case id
			when Integer
        @all[id] || old_new(@db.get_first_row("select * from YGODATA where id = #{id}"))
      when Symbol
				row = @db.get_first_row("select * from YGODATA where name = '#{id}'")
        @all[row['id'].to_i] || old_new(row)
      when nil
        Card.find(1)
			else
				sql = "select * from YGODATA where " << id
				sql << " order by #{order_by}" if order_by
				@db.execute(sql).collect {|row|@all[row['id'].to_i] || old_new(row)}
			end
		end
		def all
			if @all.size != @count
				sql = "select * from YGODATA where id not in (#{@all.keys.join(', ')})"
				@db.execute(sql).each{|row|old_new(row)}
			end
			@all
		end
		def cache
			@all
		end
		alias old_new new
		def new(id)
			find(id)
		end
    def load_from_ycff3(db = "E:/game/yu-gi-oh/YGODATA/YGODAT.mdb")
      require 'win32ole'
      conn = WIN32OLE.new('ADODB.Connection')
      conn.open("Provider=Microsoft.Jet.OLEDB.4.0;Data Source=" + db + ";Jet OLEDB:Database Password=paradisefox@sohu.com" )
      records = WIN32OLE.new('ADODB.Recordset')
      records.open("select EFFECT from YGOEFFECT", conn)
      stats = records.GetRows.first
      stats.unshift nil
      records.close
      
      records = WIN32OLE.new('ADODB.Recordset')
      records.open("YGODATA", conn)

      sql = ""
      while !records.EOF
=begin 坑爹呢...多行插入居然比单行慢= =
        sql << "select
          #{records.Fields.Item("CardID").value}, 
          '#{records.Fields.Item("CardPass").value}',
          '#{records.Fields.Item("SCCardName").value}',
          '#{records.Fields.Item("SCCardType").value}',
          '#{records.Fields.Item("SCDCardType").value.empty? ? NULL : records.Fields.Item("SCDCardType").value}',
          #{records.Fields.Item("CardATK").value || "NULL"}, 
          #{records.Fields.Item("CardDef").value || "NULL"}, 
          '#{records.Fields.Item("SCCardAttribute").value.empty? ? NULL : records.Fields.Item("SCCardAttribute").value}',
          '#{records.Fields.Item("SCCardRace").value.empty? ? NULL : records.Fields.Item("SCCardRace").value}',
          #{records.Fields.Item("CardStarNum").value || "NULL"},
          '#{records.Fields.Item("SCCardDepict").value}',
          #{case records.Fields.Item("ENCardBan").value; when "Normal"; 3; when "SubConfine"; 2; when "Confine"; 1; else; 0; end},
          '#{records.Fields.Item("CardEfficeType").value}',
          '#{records.Fields.Item("CardPhal").value}',
          '#{records.Fields.Item("CardCamp").value.gsub("、", "\t")}',
          '#{records.Fields.Item("CardISTKEN").value.zero? ? "NULL" : ("1\t" * records.Fields.Item("CardISTKEN").value).chomp("\t")}' "
        records.MoveNext
        unless records.EOF
          if sqlite_max_compound_select % 500 == 0
            sql << "; INSERT INTO YGODATA 
            (id,number,name,card_type,monster_type,atk,def,attribute,type,level,lore,status,stats,archettypes,mediums,tokens) "
          else
            sql << "union"
          end
        end
=end
        sql << "INSERT INTO YGODATA VALUES(
          #{records.Fields.Item("CardID").value}, 
          '#{records.Fields.Item("CardPass").value}',
          '#{records.Fields.Item("SCCardName").value}',
          '#{records.Fields.Item("SCCardType").value}',
          '#{records.Fields.Item("SCDCardType").value.empty? ? NULL : records.Fields.Item("SCDCardType").value}',
          #{records.Fields.Item("CardATK").value || "NULL"}, 
          #{records.Fields.Item("CardDef").value || "NULL"}, 
          '#{records.Fields.Item("SCCardAttribute").value.empty? ? NULL : records.Fields.Item("SCCardAttribute").value}',
          '#{records.Fields.Item("SCCardRace").value.empty? ? NULL : records.Fields.Item("SCCardRace").value}',
          #{records.Fields.Item("CardStarNum").value || "NULL"},
          '#{records.Fields.Item("SCCardDepict").value}',
          #{case records.Fields.Item("ENCardBan").value; when "Normal"; 3; when "SubConfine"; 2; when "Confine"; 1; else; 0; end},
          '#{records.Fields.Item("CardEfficeType").value}',
          '#{records.Fields.Item("CardPhal").value.split(",").collect{|stat|stats[stat.to_i]}.join("\t")}',
          '#{records.Fields.Item("CardCamp").value.gsub("、", "\t")}',
          '#{records.Fields.Item("CardISTKEN").value.zero? ? "NULL" : ("1\t" * records.Fields.Item("CardISTKEN").value).chomp("\t")}'
        );"
        records.MoveNext
      end
      @db.execute('DROP TABLE "main"."YGODATA";') rescue nil
      @db.execute('CREATE TABLE "YGODATA" (
        "id"  INTEGER NOT NULL,
        "number"  TEXT NOT NULL,
        "name"  TEXT NOT NULL,
        "card_type"  TEXT NOT NULL,
        "monster_type"  TEXT,
        "atk"  INTEGER,
        "def"  INTEGER,
        "attribute"  TEXT,
        "type"  TEXT,
        "level"  INTEGER,
        "lore"  TEXT NOT NULL,
        "status"  INTEGER NOT NULL,
        "stats"  TEXT NOT NULL,
        "archettypes"  TEXT NOT NULL,
        "mediums"  TEXT NOT NULL,
        "tokens"  TEXT,
        PRIMARY KEY ("id")
      );')
      open("1.txt", "w"){|f|f.write sql}
      @db.execute('begin transaction')
      @db.execute_batch(sql)
      @db.execute('commit transaction')
      
      @count = @db.get_first_value("select COUNT(*) from YGODATA") #重建计数
      @all.clear #清空缓存
    end
  end
  attr_accessor :id
  attr_accessor :name
  attr_accessor :type
  attr_accessor :race
  attr_accessor :attrbuite
  attr_accessor :depict
  attr_accessor :ban
  attr_accessor :adjust
  attr_accessor :effecttype
  attr_accessor :starnum
  attr_accessor :atk
  attr_accessor :def

  def initialize(hash)
    @id = hash['id'].to_i
    @number = hash['number'].to_sym
    @name = hash['name'].to_sym
    @card_type = hash['card_type'].to_sym
    @monster_type = hash["monster_type"] && hash["monster_type"].to_sym
    @atk = hash['atk'] && hash['atk'].to_i
    @def = hash['def'] && hash['def'].to_i
    @attribute = hash['attribute'] && hash['attribute'].to_sym
    @type = hash['type'] && hash['type'].to_sym
    @level = hash['level'] && hash['level'].to_i
    @lore = hash['lore']
    @status = hash['status'].to_i
    @stats = hash['stats'].split("\t").collect{|stat|stat.to_i}
    @archettypes = hash['archettypes'].split("\t").collect{|archettype|stat.to_sym}
    @mediums = hash['mediums'].split("\t").collect{|medium|medium.to_sym}
    @tokens = hash['tokens'] && hash['tokens'].split("\t").collect{|token|token.to_i}

    Card.cache[@id] = self
    def image
      @image ||= Surface.load "#{PicPath}/#{@id-1}.jpg"
    end
    def image_small
      #SDL::Surface#transform_surface(bgcolor,angle,xscale,yscale,flags)
      @image_small ||= image.transform_surface(0,0,54.0/image.w, 81.0/image.h,0)
    end
    def unknown?
      @id == 1
    end
  end
end
#Card.load_from_ycff3