begin
  Version = "0.1.0"
  Platform = (RUBY_PLATFORM['mswin'] || RUBY_PLATFORM['mingw']) ? :win32 : :linux

  Config = {
      'port' => 9998,
      'ygopro' => {
          'path' => ['ygocore/ygopro_vs.exe', 'ygopro_vs.exe'],
          'textfont' => ['fonts/wqy-microhei.ttc', '/usr/share/fonts/wqy-microhei/wqy-microhei.ttc', '/usr/share/fonts/truetype/wqy/wqy-microhei.ttc', 'c:/windows/fonts/simsun.ttc'],
          'numfont' => ['/usr/share/fonts/gnu-free/FreeSansBold.ttf', 'c:/windows/fonts/arialbd.ttf']
      },
      "url" => 'http://my-card.in/rooms'
  }

  Dir.chdir File.dirname(ENV["OCRA_EXECUTABLE"] || __FILE__)

  require 'json'
  if File.file? 'config.json'
    config = open('config.json') { |f| JSON.load(f) }
    Config.merge! config if config.is_a? Hash
  end

  Config['ygopro']['path'] = Config['ygopro']['path'].find { |path| File.file? path } if Config['ygopro']['path'].is_a? Enumerable
  if !Config['ygopro']['path']
    require 'win32api'
    GetOpenFileName = Win32API.new("comdlg32.dll", "GetOpenFileNameW", "p", "i")


    title = "select ygopro_vs.exe"
    filter = {"ygopro_vs.exe" => "ygopro_vs.exe"}

    OFN_EXPLORER = 0x00080000
    OFN_PATHMUSTEXIST = 0x00000800
    OFN_FILEMUSTEXIST = 0x00001000
    OFN_ALLOWMULTISELECT = 0x00000200
    OFN_FLAGS = OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST |
        OFN_ALLOWMULTISELECT
    szFile = (0.chr * 20481).encode("UTF-16LE")
    szFileTitle = 0.chr * 2049
    szTitle = (title+"\0").encode("UTF-16LE")
    szFilter = (filter.flatten.join("\0")+"\0\0").encode("UTF-16LE")
    szInitialDir = "\0"

    ofn =
        [
            76, # lStructSize       L
            0, # hwndOwner         L
            0, # hInstance         L
            szFilter, # lpstrFilter       L
            0, # lpstrCustomFilter L
            0, # nMaxCustFilter    L
            1, # nFilterIndex      L
            szFile, # lpstrFile         L
            szFile.size - 1, # nMaxFile          L
            szFileTitle, # lpstrFileTitle    L
            szFileTitle.size - 1, # nMaxFileTitle     L
            szInitialDir, # lpstrInitialDir   L
            szTitle, # lpstrTitle        L
            OFN_FLAGS, # Flags             L
            0, # nFileOffset       S
            0, # nFileExtension    S
            0, # lpstrDefExt       L
            0, # lCustData         L
            0, # lpfnHook          L
            0 # lpTemplateName    L
        ].pack("LLLPLLLPLPLPPLS2L4")
    Dir.chdir('.') {
      p GetOpenFileName.call(ofn)
    }
    szFile.delete!("\0".encode("UTF-16LE"))
    result = szFile.encode("UTF-8")
    result = File.expand_path result
    if result
      Config['ygopro']['path'] = result
    else
      exit
    end
  end
  Config['ygopro']['textfont'] = Config['ygopro']['textfont'].find { |path| File.file? path } if Config['ygopro']['textfont'].is_a? Enumerable
  Config['ygopro']['numfont'] = Config['ygopro']['numfont'].find { |path| File.file? path } if Config['ygopro']['numfont'].is_a? Enumerable

  def save_config(config=Config)
    require 'json'
    open('config.json', 'w') { |f| JSON.dump config, f }
  end

  def registed?
    path, command, icon = register_paths
    require 'win32/registry'
    begin
      Win32::Registry::HKEY_CLASSES_ROOT.open('mycard') { |reg| return false unless reg['URL Protocol'] == path }
      Win32::Registry::HKEY_CLASSES_ROOT.open('mycard\shell\open\command') { |reg| return false unless reg[nil] == command }
      Win32::Registry::HKEY_CLASSES_ROOT.open('mycard\DefaultIcon') { |reg| return false unless reg[nil] == icon }
      Win32::Registry::HKEY_CLASSES_ROOT.open('.ydk') { |reg| return false unless reg[nil] == 'mycard' }
      Win32::Registry::HKEY_CLASSES_ROOT.open('.yrp') { |reg| return false unless reg[nil] == 'mycard' }
        #Win32::Registry::HKEY_CLASSES_ROOT.open('.deck') { |reg| return false unless reg[nil] == 'mycard' }
    rescue
      return false
    end
    true
  end

  def register_paths
    path = File.expand_path(ENV["OCRA_EXECUTABLE"] || $0)
    command = "\"#{path}\" \"%1\""
    icon = "\"#{path}\" ,0"
    [path, command, icon]
  end

  def register
    require 'win32/registry'
    path, command, icon = register_paths
    begin
      Win32::Registry::HKEY_CLASSES_ROOT.create('mycard') { |reg| reg['URL Protocol'] = path.ljust path.bytesize }
      Win32::Registry::HKEY_CLASSES_ROOT.create('mycard\shell\open\command') { |reg| reg[nil] = command.ljust command.bytesize }
      Win32::Registry::HKEY_CLASSES_ROOT.create('mycard\DefaultIcon') { |reg| reg[nil] = icon.ljust icon.bytesize }
      Win32::Registry::HKEY_CLASSES_ROOT.create('.ydk') { |reg| reg[nil] = 'mycard' }
      Win32::Registry::HKEY_CLASSES_ROOT.create('.yrp') { |reg| reg[nil] = 'mycard' }
      #Win32::Registry::HKEY_CLASSES_ROOT.create('.deck') { |reg| reg[nil] = 'mycard' }
      true
    rescue Win32::Registry::Error #Access Denied, need elevation
      if ENV["OCRA_EXECUTABLE"]
        System.elevate ENV["OCRA_EXECUTABLE"], ['register']
      else
        System.elevate Gem.ruby, [$0, 'register']
      end
      'elevated'
    end
  end


  def service
    require 'websocket-eventmachine-server'
    EventMachine.run do

      WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => Config['port']) do |ws|
        ws.onopen do
          ws.send({'version' => Version}.to_json)
        end

        ws.onmessage do |msg, type|
          ws.send parse(msg).to_json
        end

        ws.onclose do
          puts "Client disconnected"
        end
      end
    end
  end

  def load_system_conf
    system_conf = {}
    conf_path = File.join(File.dirname(Config['ygopro']['path']), 'system.conf')

    IO.readlines(conf_path, 'r:UTF-8').each do |line|
      next if line[0, 1] == '#'
      field, contents = line.chomp.split(' = ', 2)
      system_conf[field] = contents
    end if File.file? conf_path

    system_conf
  end

  def save_system_conf(system_conf)
    font, size = system_conf['textfont'] ? system_conf['textfont'].split(' ') : nil
    if Config['ygopro']['textfont'] and (!font or !File.file?(File.expand_path(font, File.dirname(Config['ygopro']['path']))) or size.to_i.to_s != size)
      require 'pathname'
      font_path = Pathname.new(Config['ygopro']['textfont'])
      font_path = font_path.relative_path_from(Pathname.new(File.dirname(Config['ygopro']['path']))) if font_path.relative?
      system_conf['textfont'] = "#{font_path} 14"
    end

    font = system_conf['numfont']
    if Config['ygopro']['numfont'] and (!font or !File.file?(File.expand_path(font, File.dirname(Config['ygopro']['path']))))
      require 'pathname'
      font_path = Pathname.new(Config['ygopro']['numfont'])
      font_path = font_path.relative_path_from(Pathname.new(File.dirname(Config['ygopro']['path']))) if font_path.relative?
      system_conf['numfont'] = font_path
    end
    open(File.join(File.dirname(Config['ygopro']['path']), 'system.conf'), 'w:UTF-8') { |file| file.write system_conf.collect { |key, value| "#{key} = #{value}" }.join("\n") }
  end

  module System
    module_function

    def open(path=Config['url'], *args)
      require 'win32ole'
      $shell ||= WIN32OLE.new('Shell.Application')
      $shell.ShellExecute(path, *args)
    end

    def elevate(path, args, pwd = Dir.pwd)
      open path, args.join(' '), Dir.pwd, 'runas'
    end
  end

  def run_ygopro(parameter)
    System.open(Config['ygopro']['path'], parameter, File.dirname(Config['ygopro']['path']))
  end

  def join(room)
    options = load_system_conf
    room['user'] = local_user(options) if !room['user']['nickname']
    if room['server']['auth'] and room['user']['password']
      options['nickname'] = "#{room['user']['nickname']}$#{room['user']['password']}"
    else
      options['nickname'] = room['user']['nickname']
    end
    options['lastip'] = room['server']['ip']
    options['lastport'] = room['server']['port'].to_s
    options['roompass'] = room['name']
    save_system_conf(options)
    run_ygopro('-j')
  end

  def deck(deck)
    File.rename(File.join(File.dirname(Config['ygopro']['path']), 'deck', deck + '.ydk'), File.join(File.dirname(Config['ygopro']['path']), 'deck', deck.gsub!(' ', '_') + '.ydk')) if deck[' ']
    options = load_system_conf
    options['lastdeck'] = deck
    save_system_conf(options)
    run_ygopro('-d')
  end

  def replay(replay)
    require 'fileutils'
    moved_replay_directory = File.expand_path(File.dirname(Config['ygopro']['path'])) == Dir.pwd ? 'replay_moved' : 'replay'
    files = Dir.glob(File.join(File.dirname(Config['ygopro']['path']), 'replay', '*.yrp')) - File.join(File.dirname(Config['ygopro']['path']), 'replay', replay+'.yrp')
    FileUtils.mv files, moved_replay_directory
    run_ygopro('-r')
  end

  def local_user(system_conf=load_system_conf)
    nickname, password = system_conf['nickname'].split('$')
    {'nickname' => nickname, 'password' => password}
  end

  def parse(command)
    case command
    when 'register'
      register
    when 'registed'
      registed?
    when 'mycard:///'
      #service
    when /mycard:\/\/(.*)/
      parse_uri(command)
    when /.*\.(?:ydk|yrp)$/
      parse_path(command) #解析函数可以分开
    end
  end

  def parse_path(path)
    require 'fileutils'
    case File.extname(path)
    when '.ydk'
      deck_directory = File.join(File.dirname(Config['ygopro']['path']), 'deck')
      Dir.mkdir(deck_directory) unless File.directory?(deck_directory)
      FileUtils.copy(path, deck_directory)
      deck(File.basename(path, '.ydk'))
    when '.yrp'
      replay_directory = File.expand_path(File.dirname(Config['ygopro']['path']))
      unless File.expand_path(File.dirname(path)) == replay_directory
        Dir.mkdir(replay_directory) unless File.directory?(replay_directory)
        FileUtils.copy(path, replay_directory)
      end
      replay(File.basename(path, '.yrp'))
    end
  end

  def parse_uri(uri)
    file = uri.dup.force_encoding("UTF-8")
    file.force_encoding("GBK") unless file.valid_encoding?
    file.encode!("UTF-8")

    require 'uri'

    if uri[0, 9] == 'mycard://'
      file = URI.unescape file[9, file.size-9]
      uri = "http://" + URI.escape(file)
    else
      uri = file
    end
    case file
    when /^(.*\.yrp)$/i
      require 'open-uri'
      #fix File.basename
      $1 =~ /(.*)(?:\\|\/)(.*?\.yrp)/
      src = open(uri, 'rb') { |src| src.read }
      Dir.mkdir("replay") unless File.directory?("replay")
      open('replay/' + $2, 'wb') { |dest| dest.write src }
      replay('replay/' + $2)
    when /^(.*\.ydk)$/i
      require 'open-uri'
      #fix File.basename
      $1 =~ /(.*)(?:\\|\/)(.*?)\.ydk/
      src = open(uri, 'rb') { |src| src.read }
      Dir.mkdir(File.join(File.dirname(Config['ygopro']['path']), 'deck')) unless File.join(File.dirname(Config['ygopro']['path']), 'deck')
      open(File.join(File.dirname(Config['ygopro']['path']), 'deck', $2+'.ydk'), 'wb') { |dest| dest.write src }
      deck($2)
    when /^(?:(.+?)(?:\:(.+?))?\@)?([\d\.]+)\:(\d+)(?:\/(.*))$/
      join({
               'name' => $5.to_s,
               'user' => {
                   'nickname' => $1,
                   'password' => $2
               },
               'server' => {
                   'ip' => $3,
                   'port' => $4.to_i,
                   'auth' => !!$2
               }
           })
    end
  end

  save_config

  if ARGV.first
    puts parse(ARGV.first).to_json
  else
    register if !registed?
    System.open(Config['url'])
    #service

    #require all, for ocra
    require 'open-uri'
    require 'pathname'
    require 'win32api'

  end
rescue => exception
  open('error.txt', 'w') { |f| f.write ([exception] + exception.backtrace).join("\r\n") }
  exec 'notepad error.txt'
end


