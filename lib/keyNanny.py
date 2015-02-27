'''
#usage:
from keyNanny import KeyNanny
kn = KeyNanny(SOCKETFILE='/path/to/socket', LOGGER = '/path/to/log')
kn.set("foo", "bar")
value = kn.get("foo")
print value['DATA']
#kn.link("str1", "str2")
#kn.list()
'''

import logging
import sys
import os, stat
import socket

class KeyNanny:
	def __init__(self, **kwargs):
		try:
			log = kwargs.pop('LOGGER')
			logging.basicConfig(filename=log, level=logging.DEBUG)
		except:
			logging.warning('init: log file not specified')
			logging.basicConfig(level=logging.DEBUG)	
		try:
			self.SOCKETFILE = kwargs.pop('SOCKETFILE')
		except: 
			logging.error('init: No socketfile specified')
			sys.exit('init: No socketfile specified')		
		self.init_socket()
		
	def init_socket(self):
		try:
			mode=os.stat(self.SOCKETFILE).st_mode
		except:
			logging.error('init_socket: %s does not exist' % self.SOCKETFILE)
			sys.exit('init_socket: %s does not exist' % self.SOCKETFILE)
		if not stat.S_ISSOCK(mode):
			logging.error('init_socket: %s is not a socket file', self.SOCKETFILE)
			sys.exit('init_socket: %s is not a socket file' % self.SOCKETFILE)
		if not stat.S_IRUSR & mode:
			logging.error('init_socket: %s is not readable', self.SOCKETFILE)
			sys.exit('init_socket: %s is not readable' % self.SOCKETFILE)
		if not stat.S_IWUSR & mode:
			logging.error('init_socket: %s is not writable', self.SOCKETFILE)
			sys.exit('init_socket: %s is not writable' % self.SOCKETFILE)
		
		try:
			self.SOCKET = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			self.SOCKET.connect(self.SOCKETFILE)
		except socket.error as err:
			self.SOCKET.close()
			self.SOCKET = None
			logging.error('init_socket: Cannot connect with server, error: %s' %(err))
		
	def get(self, *arg):
		self.init_socket()
		self.send_command({'CMD': 'get', 'ARG': arg})
		return self.receive_response()
	
	def send_command(self, args):
		if not args['CMD']:
			logging.error("send_command: No command specified")
			sys.exit("send_command: No command specified")
		self.send({'DATA': " ".join([args['CMD']] + list(args['ARG']))})
		
	def send(self, args):
		if not 'BINARY' in args:
			args['DATA'] += '\r\n'
		try:
			self.SOCKET.sendall(args['DATA'])
		except socket.error:
			logging.error("send: sending through socket failed")
			sys.exit("send: sending through socket failed")

	def receive_response(self):
		return self.receive()
		
	def receive(self):
		code = self.read_line()
		result = {}
		if not ' ' in code:
			result['STATUS'] = code
			result['MESSAGE'] = ''
			return result
		else:
			status, message = code.split(' ', 1)
			if not status == 'OK':
				logging.error("receive: Server responded with error")
				result['STATUS'] = status
				result['MESSAGE'] = message
			else:
				l = int(message)
				logging.info("receive: Succesfully received answer from server")
				result['STATUS'] = status
				result['MESSAGE'] = message.rstrip()
				result['DATA'] = self.read_line(l)
			return result

	def read_line(self, *num):
		chars = []
		if num:
			try:
				a = self.SOCKET.recv(*num)
			except socket.error, e:
				logging.warning("%s" % e)
				return ""
			return a.rstrip()
		while True:
			try:
				a = self.SOCKET.recv(1)
			except socket.error, e:
				logging.warning("%s" % e)
				return ""
			if a == "\n" or a == "":
				return "".join(chars)
			chars.append(a)   
			  
	def set(self, key, value):
		self.init_socket()
		self.send_command({'CMD': 'set', 'ARG': [key, str(len(value))]})
		self.send({'DATA': value, 'BINARY': 1})
		return self.receive_response()
		
	def list(self):
		self.init_socket()
		self.send_command({'CMD': 'list', 'ARG': []})
		result = self.receive_response()
		if result['STATUS'] == 'OK':
			result['KEYS'] = result['DATA'].split()
		else:
			logging.error('list: error getting list of keys: %s:%s' %(result['STATUS'], result['MESSAGE']))
		return result
		
	def ping(self):
		self.init_socket()
		self.send_command({'CMD': 'ping', 'ARG': []})
		return self.receive_response()

	def link(self, dest, origin):
		self.init_socket()
		self.send_command({'CMD': 'link', 'ARG': [dest, origin]})
		return self.receive_response()
