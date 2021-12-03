import json

# Given Values
nested_obj = {'a':{'b':{'c':{'d':'e'}}}}
keyToSearch = "a/b/c/d"

#Function to retrieve the value form object based on key

def readValueUsingKey(queObj, keyToSearch):
    #var = json.load(queObj)
    keySearchList = keyToSearch.split('/')
    
    keyLength = len(keySearchList)
    counter=0
    for i in keySearchList:
        counter+=1
        queObj=queObj[i];
        if counter==keyLength:
           print(queObj)
           #print(literal_eval(queObj[i]))
readValueUsingKey(nested_obj,keyToSearch)

