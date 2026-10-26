((:id "r1:git-status:mx"
  :commands (:git-status)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a tracked file"
  :outcome "M-x displays the real Git status"
  :observe (:screen_text)
  :scenario "git/real-git-status-success"
  :lane "W3-11")
(:id "r1:git-diff:mx"
  :commands (:git-diff)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a working-tree edit"
  :outcome "M-x displays the real unstaged diff"
  :observe (:screen_text)
  :scenario "git/real-git-diff-success"
  :lane "W3-11")
(:id "r1:git-stage-file:mx"
  :commands (:git-stage-file)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with an unstaged edit"
  :outcome "M-x stages the file in the real index"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-stage-success"
  :lane "W3-11")
(:id "r1:git-diff-staged:mx"
  :commands (:git-diff-staged)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a staged edit"
  :outcome "M-x displays the real staged diff"
  :observe (:screen_text)
  :scenario "git/real-git-diff-staged-success"
  :lane "W3-11")
(:id "r1:git-unstage-file:mx"
  :commands (:git-unstage-file)
  :rule :r1
  :entry "mx"
  :state "temporary Git repository with a staged edit"
  :outcome "M-x removes the edit from the real index"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-unstage-success"
  :lane "W3-11")
(:id "r1:git-status:key:%7B%22keymap%22%3A%22global%22%2C%22sequence%22%3A%5B%7B%22key%22%3A%22x%22%2C%22modifiers%22%3A%5B%22control%22%5D%7D%2C%7B%22key%22%3A%22g%22%2C%22modifiers%22%3A%5B%5D%7D%5D%7D"
  :commands (:git-status)
  :rule :r1
  :entry "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"g\",\"modifiers\":[]}]}"
  :state "temporary Git repository with a newly created untracked file"
  :outcome "C-x g refreshes status to display the new file"
  :observe (:screen_text)
  :scenario "git/real-git-status-success"
  :lane "W3-11")
(:id "r5:git-status:git:success"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-status-success"
  :lane "W3-11")
(:id "r5:git-status:git:missing"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-status-missing"
  :lane "W3-11")
(:id "r5:git-status:git:nonzero"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository with a real Git error route"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-status-nonzero"
  :lane "W3-11")
(:id "r5:git-status:git:interrupted"
  :commands (:git-status)
  :rule :r5
  :entry "M-x git-status"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-status-interrupted"
  :lane "W3-11")
(:id "r5:git-diff:git:success"
  :commands (:git-diff)
  :rule :r5
  :entry "M-x git-diff"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-diff-success"
  :lane "W3-11")
(:id "r5:git-diff:git:missing"
  :commands (:git-diff)
  :rule :r5
  :entry "M-x git-diff"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-missing"
  :lane "W3-11")
(:id "r5:git-diff:git:nonzero"
  :commands (:git-diff)
  :rule :r5
  :entry "M-x git-diff"
  :state "temporary Git repository with a real Git error route"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-nonzero"
  :lane "W3-11")
(:id "r5:git-diff:git:interrupted"
  :commands (:git-diff)
  :rule :r5
  :entry "M-x git-diff"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-interrupted"
  :lane "W3-11")
(:id "r5:git-stage-file:git:success"
  :commands (:git-stage-file)
  :rule :r5
  :entry "M-x git-stage-file"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-stage-success"
  :lane "W3-11")
(:id "r5:git-stage-file:git:missing"
  :commands (:git-stage-file)
  :rule :r5
  :entry "M-x git-stage-file"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-stage-file-missing"
  :lane "W3-11")
(:id "r5:git-stage-file:git:nonzero"
  :commands (:git-stage-file)
  :rule :r5
  :entry "M-x git-stage-file"
  :state "temporary Git repository with a real Git error route"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-stage-file-nonzero"
  :lane "W3-11")
(:id "r5:git-stage-file:git:interrupted"
  :commands (:git-stage-file)
  :rule :r5
  :entry "M-x git-stage-file"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-stage-file-interrupted"
  :lane "W3-11")
(:id "r5:git-diff-staged:git:success"
  :commands (:git-diff-staged)
  :rule :r5
  :entry "M-x git-diff-staged"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:screen_text)
  :scenario "git/real-git-diff-staged-success"
  :lane "W3-11")
(:id "r5:git-diff-staged:git:missing"
  :commands (:git-diff-staged)
  :rule :r5
  :entry "M-x git-diff-staged"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-staged-missing"
  :lane "W3-11")
(:id "r5:git-diff-staged:git:nonzero"
  :commands (:git-diff-staged)
  :rule :r5
  :entry "M-x git-diff-staged"
  :state "temporary Git repository with a real Git error route"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-staged-nonzero"
  :lane "W3-11")
(:id "r5:git-diff-staged:git:interrupted"
  :commands (:git-diff-staged)
  :rule :r5
  :entry "M-x git-diff-staged"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-diff-staged-interrupted"
  :lane "W3-11")
(:id "r5:git-unstage-file:git:success"
  :commands (:git-unstage-file)
  :rule :r5
  :entry "M-x git-unstage-file"
  :state "temporary Git repository"
  :outcome "success"
  :observe (:external_state :screen_text)
  :scenario "git/real-git-unstage-success"
  :lane "W3-11")
(:id "r5:git-unstage-file:git:missing"
  :commands (:git-unstage-file)
  :rule :r5
  :entry "M-x git-unstage-file"
  :state "temporary Git repository without Git on PATH"
  :outcome "missing"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-unstage-file-missing"
  :lane "W3-11")
(:id "r5:git-unstage-file:git:nonzero"
  :commands (:git-unstage-file)
  :rule :r5
  :entry "M-x git-unstage-file"
  :state "temporary Git repository with a real Git error route"
  :outcome "nonzero"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-unstage-file-nonzero"
  :lane "W3-11")
(:id "r5:git-unstage-file:git:interrupted"
  :commands (:git-unstage-file)
  :rule :r5
  :entry "M-x git-unstage-file"
  :state "temporary Git repository with a terminating Git wrapper"
  :outcome "interrupted"
  :observe (:screen_text :file_bytes :external_state)
  :scenario "git/real-git-unstage-file-interrupted"
  :lane "W3-11"))
