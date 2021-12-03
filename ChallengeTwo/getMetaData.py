import requests
import json


def get_meta_data(url, dictionary):
    """
    This function fetches metadata recursively with the given URL and stores in the dictionary in form of key-value pairs.
    :param url: The URL to fetch Meta data property.
    :param dictionary: Reference of the object where the fetched details are stored.
    :return: None. In place updates for the provided dictionary.
    """
    print("zero...")

    response_text = requests.get(url).text

    print("one..." + response_text)

    for key in response_text.split('\n'):
        newurl = f'{url}{key}'
        if key.endswith('/'):
            newkey = key.split('/')[-2]
            dictionary[newkey] = {}
            get_meta_data(newurl, dictionary[newkey])

        else:
            value_resp = requests.get(newurl).text
            try:
                dictionary[key] = json.loads(value_resp)
            except:
                dictionary[key] = value_resp


metaurl = 'http://169.254.169.254/latest/meta-data/'

metadict = {}

print("===============================")
print("Fetching Metadata...")
try:
    get_meta_data(metaurl, metadict)
    print("Metadata Fetched.")

    with open("aws_metadata.json", "w+") as f:
        f.write(json.dumps(metadict, indent=4))

    print("AWS Metadata written to file aws_metadata.json")

except:
    print("Error while fetching meta-data !")