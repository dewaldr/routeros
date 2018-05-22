#Parse and print metadata stored in the Simple Queue Comments
#The comment format is: sitename!gigsallowed#who-to-email!last-warning-level (0-50-75-90-99)#bytes-total!cap-type (U|C)
:local sqid;

#For each simple queue, extract the comment and parse into variables
:foreach sqid in=[/queue simple find comment !=""] do={
    :local sqname [/queue simple get $sqid name];
    :local content [/queue simple get $sqid comment];

    :if ([:find $content "!"] != "") do={
        :local contlen [:len $content];
        :local pos1 [:find $content "!"];
        :local pos2 ([:find [:pick $content ($pos1+1) $contlen] "#"] + ($pos1+1));
        :local pos3 ([:find [:pick $content ($pos2+1) $contlen] "!"] + ($pos2+1));
        :local pos4 ([:find [:pick $content ($pos3+1) $contlen] "#"] + ($pos3+1));
        :local pos5 ([:find [:pick $content ($pos4+1) $contlen] "!"] + ($pos4+1));
        :local sitename [:pick $content 0 $pos1];
        :local gigs [:pick $content ($pos1+1) $pos2];
        :local email [:pick $content ($pos2+1) $pos3];
        :local warnlevel [:pick $content ($pos3+1) $pos4];
        :local savedbytes [:pick $content ($pos4+1) $pos5];
        :local captype [:pick $content ($pos5+1) $contlen];

        #Retrieve and parse usage data
        :local usage [/queue simple get $sqid bytes]

        :local pos11 [:find $usage "/"]
        :local ulen [:len $usage]

        :local bytesup ([:pick $usage 0 $pos11])
        :local megsup ($bytesup / 1048576)

        :local bytesdown ([:pick $usage ($pos11+1) $ulen])
        :local megsdown ($bytesdown / 1048576)

        :local bytestotal ($bytesup + $bytesdown + $savedbytes)
        :local percentage (($bytestotal * 100) / ($gigs * 1073741824))

        put ("Metadata for $sqname: $sitename,$gigs,$email,$warnlevel,$savedbytes,$captype");
        put ("Usage for $sqname: bytes up = $bytesup, bytes down = $bytesdown, bytes total = $bytestotal, usage = $percentage%")
    }
}
