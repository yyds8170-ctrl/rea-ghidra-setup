# domain-fixture sample module for inspect-python-pyc
SECRET_FLAG = "DOMFIX-2026"

def greet(name):
    """Return a fixed greeting string."""
    message = "hello, " + name
    return message

class Counter:
    def __init__(self, start=0):
        self.value = start
    def increment(self):
        self.value += 1
        return self.value
