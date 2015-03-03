'''
#usage:
from keyNanny import KeyNanny
kn = KeyNanny(socketfile='/path/to/socket', logger = '/path/to/log')
kn.set("foo", "bar")
value = kn.get("foo")
print value['DATA']
#kn.ping()
#kn.link("str1", "str2")
#kn.list()
'''
import logging
import socket

class KeyNanny:
	def __init__(self, **kwargs):
		socket = None
		socketfile = None
		for key in kwargs:
			if key == 'logger':
				logfile = kwargs[key]	
			elif key == 'socketfile':
				socketfile = kwargs[key]
			elif key == 'socket':
				socket = kwargs[key]
		if socket:
			if socketfile:
				raise Exception("socket and socketfile are mutually exclusive")
			self._socket = socket
		elif socketfile:
			self._init_socket(socketfile)
		else:
			raise Exception("please specify socket OR socketfile")
		logging.basicConfig(filename=logfile, level=logging.DEBUG)
		
	def _init_socket(self, socketfile):
		self._socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
		self._socket.connect(socketfile)
		logging.info('init_socket: Succesfully created socket %s' % socketfile)
	
	def _send_command(self, cmd, args = None, binary=None):
		if isinstance(args, str):
			args = [args]
		if args is None:
			args = []
		self._send(" ".join([cmd] + args), binary)
		
	def _send(self, args, binary=None):
		if binary is None:
			args += '\r\n'
		self._socket.sendall(args)
		
	def _receive(self):
		code = self._read_line()
		result = {}
		if not ' ' in code:
			result['STATUS'] = code.rstrip()
			result['MESSAGE'] = ''
			return result
		else:
			status, message = code.split(' ', 1)
			if status != 'OK':
				logging.error("receive: Server responded with error")
				result['STATUS'] = status.rstrip()
				result['MESSAGE'] = message.rstrip()
			else:
				l = int(message)
				logging.info("receive: Succesfully received answer from server")
				result['STATUS'] = status.rstrip()
				result['MESSAGE'] = message.rstrip()
				result['DATA'] = self._read_line(l)
			return result

	def _read_line(self, num=None):
		"read a line from a socket or num chars if given"
		chars = []
		if num:
			a = self._socket.recv(num)
			return a.rstrip()
		while True:
			a = self._socket.recv(1)
			if a == "\n" or a == "":
				return "".join(chars)
			chars.append(a)   
	
	def get(self, arg):
		self._send_command('get', arg)
		return self._receive()
			  
	def set(self, key, value):
		self._send_command('set', [key, str(len(value))])
		self._send(value, True)
		return self._receive()
		
	def list(self):
		self._send_command('list')
		result = self._receive()
		if result['STATUS'] == 'OK':
			result['KEYS'] = result['DATA'].split()
		else:
			logging.error('list: error getting list of keys: %s:%s' %(result['STATUS'], result['MESSAGE']))
		return result
		
	def ping(self):
		self._send_command('ping')
		return self._receive()

	def link(self, dest, origin):
		self._send_command('link', [dest, origin])
		return self._receive()
