gen=Random.new()

#####################################################################################################################

puts	"Usage: <times>d<size>(+<mod>)(-<mod>(drop <lo/hi> <n>)(times <n>)(trim).\n'q' to quit, 'r' to repeat last command. 'v' to change verbosity. 'c' to change copying result to clipboard. 'h' for help. 'x=y' to alias 'y' as 'x'. 'a' to print aliases."

help=Hash.new
help['r']="Repeats the last valid command."
help['v']="Flips verbosity. Default is verbose."
help['c']="Flips copying to clipboard mode. Default is on."
help['h']="Prints help for commands."
help['drop']="'drop' drops n of the lowest or highest rolls. (e.g. '4d6 drop lo 1' for a standard D&D stat roll)."
help['+']="'+' adds mod to your roll. You can combine multiple of these and the '-' modifiers (e.g. '1d20+5-2')."
help['-']=" '-' subtracts mod from your roll. You can combine multiple of these and the '+' modifiers. (e.g. '1d20+5-2')"
help['times']="'times' makes the roll repeat n times (e.g. '2d6 times 2' will roll 2d6 twice)."
help['trim']="'trim' causes verbosity to flip for the command."
help['keywords']="'lo', 'hi' and 'trim' keywords only require the first letter to match (e.g. '2d20 drop lowest 1 trim' is the same as '2d20 drop l 1 t')."
help['whitespace']="The interpreter ignores whitespaces (e.g. '4d6 drop lowest 1 trim' is the same as '4d6droplowest1trim')."

help_subjects=''
help_all=''
help.each_with_index do |x, i|
	help_subjects= help_subjects + "'" + x[0] + "'"
	help_all=help_all+x[1]+"\n"
	help_subjects= help_subjects + ' ' unless i==help.size-1
end
help_default="Use 'h <subject>' for help on the subject. Use 'h all' to print all help."

#####################################################################################################################

last_cmd=''
n=1
full_out=''
default_trim=false
trim=default_trim
defaultFormat='%r: %D; %RR %Rr total %t'
trimFormat='%Rr %t'

#####################################################################################################################

clipboard=''

clipboard='clip' if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
clipboard='pbcopy' if (/darwin/ =~ RUBY_PLATFORM) !=nil
clipboard=`xsel --clipboard -input` if clipboard==''

noclip=false
noclip=true if clipboard==''

puts "Clipboard not accessible! Defaulting clipboard copying to off and disabling switching." if clipboard==''

#####################################################################################################################

aliasTable=Hash.new

if FileTest.file?('alias.ini')
	iniFile=File.open('alias.ini','r')
	iniFile.each_line do |x|
		if (aliasing=/(\w+)\=(.+)/.match(x))!=nil
			aliasTable[aliasing[1]]=aliasing[2]
		end
	end
	iniFile.close
end

#####################################################################################################################

def diceInterpret(input, gen, format)
	output=''
	outputParts=Hash.new
	
	if (cmd=/(?<roll>(?<times>\d+)[dD](?<die>\d+))\s*(?<add>(?:\s*[\+|\-]\s*\d+)*)?\s*(?:(?<drop>drop)\s*(?<dropmod>l|h)\w*\s*(?<dropN>\d)\s*\z|\z)/i.match(input))!=nil
		outputParts['%r']=cmd['roll']
		outputParts['%t']=cmd['times']
		outputParts['%d']=cmd['die']
		outputParts['%RR']=''
		outputParts['%Rr']=''
		outputParts['%Srr']=''
		outputParts['%D']=''
		outputParts['%a']=''
		outputParts['%s']=''
		outputParts['%As']=''
		outputParts['%t']=''
		
		dice=Array.new()
		cmd['times'].to_i.times do
			cmd['die'].to_i!=0 ? dice.push(gen.rand(cmd['die'].to_i)+1) : dice.push(0)
		end
		dice=dice.sort
		
		sum=0

		outputParts['%D']=dice.join(', ')
		
		sum=dice.inject { |s, n| s+n.to_i}
		
		if cmd['drop']!=nil
			if cmd['dropN'].to_i>=dice.size
				outputParts['%RR']="dropped all dice;"
			else
				outputParts['%RR']="dropping " + (cmd['dropN']=='1' ? "the" : cmd['dropN']) + (cmd['dropmod']=='l' ? " lowest" : " highest") + (cmd['dropN']==1 ? " die;" : " dice;")
			end
			
			cmd['dropmod']=='l' ? dice=dice.drop(cmd['dropN'].to_i) : dice.pop(cmd['dropN'].to_i)
			sum=0
			outputParts['%Rr']=''
			for i in 0..dice.size-1
				if i!=dice.size-1
					outputParts['%Rr'] << dice[i].to_s + ", "
				else
					outputParts['%Rr'] << dice[i].to_s
				end
				sum=sum+dice[i]
			end
			outputParts['%Srr']=sum.to_s
			outputParts['%Rr'] << ';' unless dice.size==0
			
		end
		outputParts['%t']=sum.to_s
		outputParts['%As']=sum.to_s
		
		addition=cmd['add'].gsub(/\s+/, "")
		if addition!=""
			add=addition.scan(/\+|\-|\d+/)
			outputParts['%a'] << addition
			outputParts['%t'] << addition + '='
			
			i=0
			while i<add.size-1
				if add[i]=='+'
					sum=sum+add[i+1].to_i
				else
					sum=sum-add[i+1].to_i
				end
				i=i+2
			end
			outputParts['%t'] << sum.to_s
		end
		outputParts['%s']=sum.to_s
		fOutput=''
		fOutput << format
		(while fOutput.gsub!(/(#{outputParts.keys.join('|')})/, outputParts); end) unless outputParts.empty?
		output << fOutput.squeeze(" ").lstrip.rstrip
	else
		output=nil
	end
	return output
end

#####################################################################################################################

loop do
	input=gets().chomp
	break if input=='q'
	if input=='r'
		if last_cmd!=''
			input=last_cmd
		else
			puts 'No valid command in history! Please issue a valid command before attempting to repeat.'
		end
	end
	if input=='v'
		default_trim=!default_trim
		puts "Switched output to be " + (default_trim ? "less" : "more") + " verbose."
		redo
	end
	if input=='c'
		noclip=!noclip unless clipboard==''
		puts "Switched clipboard copying to " + (noclip ? "off." : "on.")
		redo
	end
	if (h=/(^h)\s*(.+)?/i.match(input))!=nil
		if h[2]==nil
			puts "Help subjects: " + help_subjects + "\n\n" + help_default + "\n"
		elsif h[2]=='all'
			puts help_all
		else
			puts help[h[2]] != nil ? help[h[2]] : "Invalid subject!"
		end
		redo
	end
	if (aliasing=/(\w+)\=(.+)/.match(input))!=nil
		aliasTable[aliasing[1]]=aliasing[2]
		puts "Aliasing '#{aliasing[2]}' to '#{aliasing[1]}"
		iniFile=File.open('alias.ini','w+')
		aliasTable.each do |x|
			iniFile << x[0] + '=' + x[1] + "\n"
		end
		iniFile.close
		redo
	end
	(while input.gsub!(/\b(#{aliasTable.keys.join('|')})\b/, aliasTable); end) unless aliasTable.empty?
	parR=0
	while (parR=input.rindex('(')) != nil
		parL=0
		if (parL=input.index(')', parR)) == nil
			puts 'Mismatched parentheses!'
			redo
		end
		result=diceInterpret(input[parR+1..parL-1], gen, '%s')
		if result==nil
			puts "Invalid format within parenthesis! Please use the format <times>d<size>(+<mod>)(-<mod>(drop <lo/hi> <n>)(times <n>)(trim)"
			redo
		end
		input[parR..parL]=result
	end
	if input=='a'
		aliasTable.each do |x|
			puts x[0] + '=' + x[1]
		end
		redo
	end
	
	
	full_out=''
	n=1
	trim=default_trim
	
	if (trimmed=/(?<cmd>^.*)?(?<trim>t)\w*\s*\z/i.match(input)) != nil
		input=trimmed['cmd']
		trim=!default_trim
	end
	
	if (times=/(?<cmd>^.*)?(?<repeat>times)\s*(?<times>\d+)/i.match(input)) != nil
		input=times['cmd']
		n=times['times'].to_i
	end
	
	if n==0
		puts "Nothing will be done 0 times."
	end
	
	n.times do |iteration|
		output=diceInterpret(input, gen, trim ? trimFormat : defaultFormat)
		if output==nil
			puts "Invalid format! Please use the format <times>d<size>(+<mod>)(-<mod>(drop <lo/hi> <n>)(times <n>)(trim)"
			break
		end
		last_cmd=input
		iteration!=n-1 ? full_out=full_out+output+"\n" : full_out=full_out+output
	end
	IO.popen(clipboard, 'w') { |f| f << full_out } unless noclip
	puts full_out unless full_out==''
end	