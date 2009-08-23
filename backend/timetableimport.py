#!/usr/bin/python
import sys
import xml.sax
import re
import MySQLdb

mysql = MySQLdb.connect(#host="192.168.144.45",
                        host="localhost",
                        user="root",
                        db="howsmytrain")

class ParseObjects(xml.sax.ContentHandler):
    def __init__(self):
        self.train = None
        self.trains = []

    def startElement(self, name, attr):
        if name == "trains":
            self.train = {'stations': [], 'day': None, 'id': None}
            self.parseDays(attr['day'])

        elif name == "stations":
            #print attr['name']
            c = mysql.cursor()
            c.execute("SELECT crs FROM stations WHERE name=\"%s\";" % attr['name'])
            row = c.fetchone()
            name = row[0]
            c.close()
            #print name

            if len(self.train['stations']) and self.train['stations'][-1][0] == name:
                pass
            else:
                self.train['stations'].append([name])

        elif name == "a" or name == "d":
            if attr.has_key('hour') and not (attr.has_key('connection') and attr['connection'] == '1'):
                time = "%s:%s" % (attr['hour'], attr['min'])
                #print self.train['stations']
                self.train['stations'][-1].append(time)

    def endElement(self, name):
        if name == "trains" and self.train['stations']:
            crsd = self.train['stations'][0][0]
            crsa = self.train['stations'][-1][0]
            td = self.train['stations'][0][1]
            ta = self.train['stations'][-1][1]

            del(self.train['stations'][-1])
            for day in self.train['day']: 
                id = "%s-%s-%s-%s-%s" % (crsd, crsa, td, ta, day)
                train = self.train.copy()
                train['id'] = id
                train['day'] = day
                self.trains.append(train)

        elif name == "stations":
            if len(self.train['stations'][-1]) == 1:
                del(self.train['stations'][-1])

    def parseDays(self, str):
        days = {'Mondays': 1, 'Fridays': 5, 'Saturdays': 6, 'Sundays': 7}
        result = re.match("(\w+)( to (\w+))?", str)
        if result.group(3):
            self.train['day'] = range(days[result.group(1)], days[result.group(3)]+1)
        else:
            self.train['day'] = [days[result.group(1)]]

        #print self.train['day']

def insertRows(s):
    c = mysql.cursor()
    sql = "INSERT INTO timetables (ServiceID, Day, StopsAt, StopsWhen) VALUES %s" % ','.join(s)
    try:
        c.execute(sql)
    except _mysql_exceptions.ProgrammingError, e:
        print sql
        raise e
    c.close()
    return c.rowcount


parser = ParseObjects()
xml.sax.parse(sys.argv[1], parser)

i = 0
j = 0
s = []
for train in parser.trains:
    for stop in train['stations']:
        s.append("('%s', '%s', '%s', '%s')" % (train['id'], train['day'], stop[0], stop[1]))
        i += 1
        if i > 99:
            j += insertRows(s)
            i = 0
            s = []
j += insertRows(s)
print "Inserted %s rows in total" % j

