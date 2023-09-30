import sys
import re
import os.path

CONFIG_PATTERN = r'\bconfig\s+\S+\s+[\'\"]?([^\s\'\"]+)[\'\"]?'
OPTION_PATTERN = r'\boption\s+(\S+)\s+(\S+)'
LIST_PATTERN = r'\blist\s+(\S+)\s+(\S+)'
NAME_KEY = ".name"

def format_section(uci_path, file_name):
	file_path = "%s%s" % (uci_path, file_name)
	file, lines = None, []
	try:
		file = open(file_path, 'r')
		lines = file.readlines()
	except:
		print "[ERROR]can not read file:%s"%(file_path)
		return ""
	finally:
		if file:
			file.close()

	if len(lines) <= 0:
		print "[ERROR]can not read file:%s"%(file_path)
		return ""

	print "Read UCI:%s lines len = %d"%(file_path, len(lines))
	sec_list, cur_sec, cur_list = [], {}, {}
	for line in lines:
		res_conf = re.search(CONFIG_PATTERN, line)
		res_opt = re.search(OPTION_PATTERN, line)
		res_list = re.search(LIST_PATTERN, line)

		if res_conf: 
			#添加section
			cur_sec = {}
			cur_sec[NAME_KEY] = res_conf.group(1)
			sec_list.append(cur_sec)
			continue

		if res_list and cur_sec:
			#添加section list
			listname, listval = res_list.group(1), res_list.group(2)
			if not listname in cur_sec:
				cur_sec[listname] = []
			cur_sec[listname].append(listval)
			continue

		if res_opt and cur_sec:
			#添加section option
			cur_sec[res_opt.group(1)] = res_opt.group(2)
			continue

	#生成uci file字符串
	file_str = '''var uci_%s={\"%s\":{''' % (file_name, file_name)
	for sec in sec_list:
		sec_str = '''%s:{''' % sec[NAME_KEY] 
		for key in sec:
			if key == NAME_KEY:
				continue

			val = sec[key]
			if isinstance(val, list):
				opt_str = '''%s:[''' % key
				for item in val:
					opt_str = '''%s %s,''' % (opt_str, item)
				opt_str = '''%s ],''' % (opt_str[:-1])
			else:
				opt_str = '''%s:%s,''' % (key, val)

			#添加option string
			sec_str = '''%s %s''' % (sec_str, opt_str)

		#添加section string eg, '''section_name : {opt1:"3", list1:["on", "off"]},'''
		if sec_str[-1] == ',':
			sec_str = sec_str[:-1]
		sec_str = '''%s },''' % sec_str
		file_str = '''%s\n\t%s''' % (file_str, sec_str)
		
	#完成uci file处理
	file_str = '''%s\n}};''' % file_str[:-1]
	return file_str

#this is the entrance of this program
def main():
	if len(sys.argv) <= 3:
		print "Usage: input is less."
		sys.exit(-1)
	elif not isinstance(sys.argv[0], str) or not isinstance(sys.argv[1], str) or not isinstance(sys.argv[2], str):
		print "Usage: input type should be string."
		sys.exit(-1)
	else:
		#目标路径
		des_path = sys.argv[1]
		if des_path[-1] == '/':
			des_path = des_path[:-1]

		#uci文件名列表，用分号分割
		file_name_list = re.split('\W+', sys.argv[2])

		#uci文件路径，接受多个路径
		#遇到不同路径包含同一个uci文件，使用后一个路径下的uci文件
		idx = 3
		uci_path_list = []
		while idx < len(sys.argv):
			uci_path = sys.argv[idx]
			if not uci_path[-1] == '/':
				uci_path = "%s/" % uci_path
			uci_path_list.append(uci_path)
			idx = idx + 1

		res_content = ""
		list.reverse(uci_path_list)
		for file_name in file_name_list:
			for uci_path in uci_path_list:
				file_path = "%s%s" % (uci_path, file_name)
				print '>>>'+file_path
				if len(file_name) >= 0 and os.path.isfile(file_path):
					res_str = format_section(uci_path, file_name)
					res_content = "%s%s\n" % (res_content, res_str)
					break

		des_file = "%s/capability.js" % des_path
		print 'des_file>>>'+des_file
		try:
			file = open(des_file, 'w')
			file.write(res_content)
		finally:
			if file:
				file.close()

main()
