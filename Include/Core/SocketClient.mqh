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
    }

    bool Send(string data) {
        if (m_socket == INVALID_HANDLE) return false;

        char req[];
        int len = StringToCharArray(data, req) - 1; // Exclude null terminator if needed, but python reads text
        if (len < 0) len = 0;

        // MQL5 StringToCharArray includes terminal 0. Python decode().strip() handles it.

        int sent = SocketSend(m_socket, req, len);
        if (sent != len) {
            Print("SocketSend failed, error: ", GetLastError());
            return false;
        }
        return true;
    }

    bool Receive(string &data) {
        if (m_socket == INVALID_HANDLE) return false;

        char rsp[];
        string result = "";
        int totalRead = 0;

        // Simple blocking read
        // Loop until data received or timeout
        // But SocketRead reads available data.
        // We assume the server sends one response and closes or we read enough.
        // The python server sends one JSON object.

        // We read chunks
        do {
           char buffer[4096];
           int read = SocketRead(m_socket, buffer, 4096, m_timeout);
           if (read > 0) {
               string chunk = CharArrayToString(buffer, 0, read);
               result += chunk;
               // If we got a valid JSON end '}', we might stop, but JSON implies structured.
               // For simplicity, we assume one read is enough for small responses or loop if SocketIsReadable.
               // But SocketIsReadable checks for *more* data.

               // Let's rely on SocketRead with timeout. If it returns data, we append.
               // If we want to wait for full message, we need protocol.
               // Python server writes and drains.
               // We will just read once with a generous buffer for now, or loop.
               // Given SocketRead waits, we might get partial.

               // Since the Python server sends JSON, we can check for balanced braces?
               // Or just read until socket closed by server?
               // Python server implementation: `writer.write... writer.drain... writer.close... wait_closed`.
               // So the server CLOSES the connection after sending.
               // So we can read until 0 return (connection closed)?
               // SocketRead returns -1 on error. 0 if ??? (connection closed?)
           } else {
               if (GetLastError() != 0) {
                   // Error
               }
               break; // Stop loop
           }

           // If we read something, continue reading until connection closed (read==0) implies end?
           // MQL5 SocketRead returns number of bytes.
        } while (SocketIsReadable(m_socket));

        data = result;
        return (StringLen(data) > 0);
    }

    void Close() {
        if (m_socket != INVALID_HANDLE) {
            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
        }
    }
};
