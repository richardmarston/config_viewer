#!/usr/bin/ruby

require 'socket'
require 'rubygems'
require 'htmlentities'
$test=false

if (RUBY_VERSION=="1.9.3")
   require_relative 'database.rb'
else
   require 'database.rb'
end


$debug=true

def showLink(form, chain, link)
   # Create Buttons
   logButton = Element.new('input')
   logButton.add_attribute('type', 'button')
   logButton.add_attribute('value', 'Show Log')
   logButton.add_attribute('onclick', "return OnLogButton(\""+chain+"\",\""+link+"\");")
   configButton = Element.new('input')
   configButton.add_attribute('type', 'button')
   configButton.add_attribute('value', 'Show Config')
   configButton.add_attribute('onclick', "return OnConfigButton(\""+chain+"\",\""+link+"\");")

   form << logButton
   form << configButton
   form << Element.new('br')
end

def showCommand(command)
   textArea = Element.new('textarea')
   comm = HTMLEntities.new.decode(command)
   filldata = `#{comm}`
   textArea.add_text(filldata)
end

def showLog(link)
   command = link.attribute('log').to_s
   showCommand(command)
end

def showConfig(link)
   command = link.attribute('config').to_s
   showCommand(command)
end


def showChain(content, chain_name, link_log='', link_config='')
   div = Element.new('div')
   h2 = Element.new('h2')
   h2.add_text(chain_name)
   div << h2
   xpath = '//config//chain[@name="'+chain_name+'"]'
   XPath.each(content, xpath) { | chain | 
      # Create Form
      form = Element.new('form')
      form.add_attribute('name', chain_name+'form')
      form.add_attribute('method', 'get')
 
      chain.each_element { | link |
         h4 = Element.new('h4')
         h4.add_text(link.attribute('name').to_s)
         form << h4
         showLink(form, chain_name, link.attribute('name').to_s)
         if (link_log == link.attribute('name').to_s)
            form << showLog(link) 
         end
         if (link_config == link.attribute('name').to_s)
            form << showConfig(link) 
         end
      }
      div << form
   }

   # Create Script
   script = Element.new('script')
   script.add_attribute('language', 'Javascript')
   script_text = String.new("""
   function OnLogButton(chain, link)
   {
      document."+chain_name+"form.action = \"http://127.0.0.1:7125/chain/\"+chain+\"/log/\"+link;
      document."+chain_name+"form.submit();
      return true;
   }
   function OnConfigButton(chain, link)
   {
      document."+chain_name+"form.action = \"http://127.0.0.1:7125/chain/\"+chain+\"/config/\"+link;
      document."+chain_name+"form.submit();
      return true;
   }
   """)
   script.add_text(script_text)
   div << script
   div
end

def chainHome(chain_name, link_log='', link_config)
   puts "LOG: "+link_log+" CONFIG: "+link_config
   html = Element.new('html')
   html.add_attribute('lang','en')
   body = Element.new('body')
   title = body << Element.new('title')
   title.add_text('Chain: '+chain_name)
   db = Database.new
   content = db.readDefinitions
   body << showChain(content, chain_name, link_log, link_config)
end

def createMenu()
   db = Database.new
   html = Element.new('html')
   html.add_attribute('lang','en')
   body = Element.new('body')
   title = body << Element.new('title')
   title.add_text('Chains')

   content = db.readDefinitions
   content.each_element { | config |
      config.each_element { | chain |
         chain_name=chain.attribute('name').to_s
         body << showChain(content, chain_name) 
      }
   }

   html << body
   html
end

def add_labelled_input(para, name)
   label = Element.new('LABEL')
   label.add_attribute('for', name.downcase)
   label.add_text(name)
   entry = Element.new('INPUT')
   entry.add_attribute('type', 'text')
   entry.add_attribute('name', name.downcase)
   para.add(label) 
   para.add(entry)
end

def add_hidden_input(para, name, value)
   entry = Element.new('input')
   entry.add_attribute('type', 'hidden')
   entry.add_attribute('name', name)
   entry.add_attribute('value', value)
   para.add(entry)
end

def newLinkForm(chain)
   form = Element.new('form')
   form.add_attribute('action', 'http://127.0.0.1:7125/newLink.html')
   form.add_attribute('method', 'post')
   para = Element.new('P')
   add_labelled_input(para, 'Name')
   add_labelled_input(para, 'Log')
   add_labelled_input(para, 'Config')
   add_hidden_input(para, 'chain', chain)

   send_button = Element.new('INPUT')
   send_button.add_attribute('type', 'submit')
   send_button.add_attribute('value','Add')

   para << send_button
   form << para
   form 
end

def newFileTemplate(session)
    session.print()
end

def readData(session)
   content=nil
   request = session.gets
   while (request != "\r\n")
      request = session.gets
      puts "request: "+request.to_s unless $debug == false
      if request.match('Content-Length: ')
         content_length = request.to_s[16, request.length]
         puts "content_length: "+content_length unless $debug == false
         request = session.read(2)
         content = session.read(content_length.to_i)
         puts "content: "+content unless $debug == false
      end
   end
   content
end

def doGet(session, request)
   getrequest = request.gsub(/GET\ \//, '').gsub(/\ HTTP.*/, '')
   request_url = getrequest.chomp
   document = Document.new
   data=readData session
   if data != nil
      puts "data: "+data
   end
   if request_url == ""
      document << createMenu()
   else
      request_components = request_url.split('/')
      type = request_components[0]
      name = request_components[1]
      if (type == 'chain')    
         if (request_components.length == 4)
            if (request_components[2] == 'log')
               document << chainHome(name, request_components[3], '')
            elsif (request_components[2] == 'config')
               document << chainHome(name, '', request_components[3])
            end
         else    
            document << chainHome(name)
         end
         document.root << newLinkForm(name)
      else
         puts 'Did not recognise request type: '+type
         return nil
      end
   end
   #puts "\n***\n***\nDOC: "+document.to_s
   document
end

def newLink(link)
   puts ' name: '    + link['name'] + 
        ' chain: '   + link['chain'] +
        ' log: '     + link['log'] +
        ' config: '  + link['config'] unless $debug == false
   db = Database.new
   _link = ChainLink.new(link['name'], link['log'], 
                         link['config'], link['chain'])
   db.addLink(_link)
   db.saveDefinitions
   myfile = <<EOF
<!DOCTYPE HTML>
<html lang="en-US">
    <head>
        <meta charset="UTF-8" />
        <meta http-equiv="refresh" content="1;url=http://127.0.0.1:7125/chain/mychain" />
        <script type="text/javascript">
            window.location.href = "http://127.0.0.1:7125/chain/mychain"
        </script>
        <title>Adding chain link</title>
    </head>
    <body>
        If you are not redirected automatically, follow the <a href='http://127.0.0.1:7125/chain/mychain'>link to example</a>
    </body>
</html>
EOF
   myfile
end

def parseParameters(data)
   hash={}
   inputs = data.split('&')
   inputs.each { |input| 
      puts input
      tokens = input.split('=')
      puts tokens
      hash[tokens[0]] = CGI::unescape(tokens[1])
   }
   hash
end

def doPost(session, request)
   postrequest = request.gsub(/POST\ \//, '').gsub(/\ HTTP.*/, '')
   puts "postrequest: "+request.to_s unless $debug == false
   data=readData session
   document = nil
   if data != nil
      puts "data: "+data
      params=parseParameters(data)
      puts params
      document = Document.new newLink(params)
   end
   document
end

webserver = TCPServer.new('127.0.0.1', 7125)
while (session = webserver.accept)
   request = session.gets
   puts request unless $debug == false

   filename = ""
   if (request == nil)
      next
   end

   if (request.match("GET\ "))
      document=doGet(session,request)
   elsif (request.match("POST\ "))
      document=doPost(session,request)
   end
   
   if (document != nil)
      session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      docstring = HTMLEntities.new.decode(document.to_s)
      #puts "Sending: "+docstring
      session.print docstring 
      session.close
   end

   puts "done" unless $debug == false

   #if (filename != "")
   #   begin
   #      displayfile = File.open(filename, 'r')
   #      content = displayfile.read()
   #      session.print content
   #   rescue Errno::ENOENT
   #      session.print "File not found"
   #   end
   #end

   #set the attribute value delimiter
   #document.context[:attribute_quote] = :quote
end
