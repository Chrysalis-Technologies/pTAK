from FreeTAKServer.core.connection.MainSocketController import MainSocketController
from FreeTAKServer.model.sockets.SSLServerSocket import SSLServerSocket
import ssl
import socket
import os


class SSLSocketController(MainSocketController):
    def __init__(self):
        self.MainSocket = SSLServerSocket()
    def createContext(self):
        context = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_SERVER)
        context.load_verify_locations(cafile=self.MainSocket.CA)
        crl_path = getattr(self.MainSocket, "CRLFile", None)
        if crl_path and os.path.exists(crl_path):
            try:
                context.load_verify_locations(cafile=crl_path)
                context.verify_flags = ssl.VERIFY_CRL_CHECK_LEAF
            except Exception:
                context.verify_flags = 0
        else:
            context.verify_flags = 0
        context.options |= ssl.OP_NO_SSLv3
        context.options |= ssl.OP_NO_SSLv2
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_cert_chain(certfile=self.MainSocket.pemDir, keyfile=self.MainSocket.keyDir,
                                password=self.MainSocket.password, )
        return context
    def createSocket(self):
        context = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_SERVER)
        context.load_verify_locations(cafile=self.MainSocket.CA)
        crl_path = getattr(self.MainSocket, "CRLFile", None)
        if crl_path and os.path.exists(crl_path):
            try:
                context.load_verify_locations(cafile=crl_path)
                context.verify_flags = ssl.VERIFY_CRL_CHECK_LEAF
            except Exception:
                context.verify_flags = 0
        else:
            context.verify_flags = 0
        context.options |= ssl.OP_NO_SSLv3
        context.options |= ssl.OP_NO_SSLv2
        context.options |= ssl.OP_NO_TLSv1
        context.options |= ssl.OP_NO_TLSv1_1
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_cert_chain(certfile=self.MainSocket.pemDir, keyfile=self.MainSocket.keyDir,
                                password=self.MainSocket.password, )
        self.MainSocket.sock = socket.socket(self.MainSocket.socketAF, self.MainSocket.socketSTREAM)
        self.MainSocket.sock.setsockopt(self.MainSocket.solSock, self.MainSocket.soReuseAddr,
                                        self.MainSocket.sockProto)
        self.MainSocket.sock.bind((self.MainSocket.ip, self.MainSocket.port))
        #self.MainSocket.sock = context.wrap_socket(self.MainSocket.sock, server_side=True)
        return self.MainSocket.sock

    async def wrap_client_socket(self, socket):
        context = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_SERVER)
        context.load_verify_locations(cafile=self.MainSocket.CA)
        context.options |= ssl.OP_NO_SSLv3
        context.options |= ssl.OP_NO_SSLv2
        context.options |= ssl.OP_NO_TLSv1
        context.options |= ssl.OP_NO_TLSv1_1
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_cert_chain(certfile=self.MainSocket.pemDir, keyfile=self.MainSocket.keyDir,
                                password=self.MainSocket.password, )
        sock = context.wrap_socket(socket, server_side=True)
        return sock

    def createClientSocket(self, serverIP):
        context = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_CLIENT)
        context.load_verify_locations(cafile=self.MainSocket.CA)
        crl_path = getattr(self.MainSocket, "CRLFile", None)
        if crl_path and os.path.exists(crl_path):
            try:
                context.load_verify_locations(cafile=crl_path)
                context.verify_flags = ssl.VERIFY_CRL_CHECK_LEAF
            except Exception:
                context.verify_flags = 0
        context.load_cert_chain(certfile=self.MainSocket.pemDir, keyfile=self.MainSocket.keyDir,password=self.MainSocket.password)
        context.options |= ssl.OP_NO_SSLv2
        context.options |= ssl.OP_NO_SSLv3
        context.options |= ssl.OP_NO_TLSv1
        context.options |= ssl.OP_NO_TLSv1_1
        context.check_hostname = False
        self.MainSocket.sock = socket.socket(self.MainSocket.socketAF, self.MainSocket.socketSTREAM)
        self.MainSocket.sock = context.wrap_socket(self.MainSocket.sock)
        return self.MainSocket.sock
