

def is_iterable(i):
    """ Checks if i is an iterable. """
    try:
        some_object_iterator = iter(i)
        return True
    except TypeError, te:
        return False
    return False
