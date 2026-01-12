//+------------------------------------------------------------------+
//| SocketClient.mqh                                                 |
//| TCP Socket Client for communication with Python server           |
//+------------------------------------------------------------------+
#property copyright "Effata Reinforcement Trading"
#property strict

#include <Strings/String.mqh>

class CSocketClient {
private:
    int m_socket;
    string m_address;
    int m_port;
    int m_timeout;

public:
    CSocketClient(string address="127.0.0.1", int port=5555, int timeout=5000) {
        m_address = address;
        m_port = port;
        m_timeout = timeout;
        m_socket = INVALID_HANDLE;
    }

    ~CSocketClient() {
        Close();
    }

    bool SendAndReceive(string request, string &response) {
        if (!Connect()) return false;

        if (!Send(request)) {
            Close();
            return false;
        }

        if (!Receive(response)) {
            Close();
            return false;
        }

        Close();
        return true;
    }

private:
    bool Connect() {
        #ifdef __MQL5__
        m_socket = SocketCreate();
        if (m_socket == INVALID_HANDLE) {
            Print("SocketCreate failed, error: ", GetLastError());
            return false;
        }

        if (!SocketConnect(m_socket, m_address, m_port, m_timeout)) {
            Print("SocketConnect failed, error: ", GetLastError());
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
            return false;
        }
        return true;
        #else
        Print("Sockets not supported natively in MQL4 without DLL. Use MQL5 for HFT.");
        return false;
        #endif
    }

    bool Send(string data) {
        #ifdef __MQL5__
        if (m_socket == INVALID_HANDLE) return false;

        char req[];
        int len = StringToCharArray(data, req) - 1;
        if (len < 0) len = 0;

        int sent = SocketSend(m_socket, req, len);
        if (sent != len) {
            Print("SocketSend failed, error: ", GetLastError());
            return false;
        }
        return true;
        #else
        return false;
        #endif
    }

    bool Receive(string &data) {
        #ifdef __MQL5__
        if (m_socket == INVALID_HANDLE) return false;

        string result = "";

        do {
           char buffer[4096];
           int read = SocketRead(m_socket, buffer, 4096, m_timeout);
           if (read > 0) {
               string chunk = CharArrayToString(buffer, 0, read);
               result += chunk;
           } else {
               break;
           }
        } while (SocketIsReadable(m_socket));

        data = result;
        return (StringLen(data) > 0);
        #else
        return false;
        #endif
    }

    void Close() {
        #ifdef __MQL5__
        if (m_socket != INVALID_HANDLE) {
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
        }
        #endif
    }
};
